!> Part of the following code has been adapted from postg
!> Copyright (c) 2015 Alberto Otero de la Roza <aoterodelaroza@ucmerced.edu>,
!> Felix Kannemann <felix.kannemann@dal.ca>, Erin R. Johnson <ejohnson29@ucmerced.edu>,
!> Ross M. Dickson <ross.dickson@dal.ca>, Hartmut Schmider <hs7@post.queensu.ca>,
!> and Axel D. Becke <axel.becke@dal.ca>

! Copyright (c) 2009-2017 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
! Ángel Martín Pendás <angel@fluor.quimica.uniovi.es> and Víctor Luaña
! <victor@fluor.quimica.uniovi.es>. 
!
! critic2 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or (at
! your option) any later version.
! 
! critic2 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
! 
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

! molecular wavefunction readers and tools
module wfn_private
  use environmod, only: environ
  implicit none
  
  private

  ! Molecular basis set information for libCINT integral calculations
  ! * env: array that holds the double numbers for atomic coordinates,
  !   coefficients, and exponents.
  ! * atm: atom information, atm(6,natm), natm = number of atoms
  !   atm(1,n) = atomic number
  !   atm(2,n) = env offset to coordinates (minus 1, because of 0-indexing)
  !   atm(3,n) = nuclear model of atom n
  !   atm(4,n) = env offset for the nuclear charge distribution parameter
  !   atm(5:6,n) = unused
  ! * bas: shell information, bas(8,nbas), nbas = number of shells
  !   bas(1,n) = 0-based index for the atom
  !   bas(2,n) = angular momentum number
  !   bas(3,n) = number of primitive GTOs
  !   bas(4,n) = number of contracted functions
  !   bas(5,n) = kappa for spinor functions
  !   bas(6,n) = env offset for primitive GTO exponents
  !   bas(7,n) = env offset for contraction coefficients
  !   bas(8,n) = unused
  ! All input and output arrays in Fortran ordering.
  type cintdata
     logical, allocatable :: lsph !< whether primitives are spherical or Cartesian
     real*8, allocatable :: moc(:,:) ! molecular orbital coefficients
     integer :: natm !< number of atoms
     integer :: nbas !< number of shells (basis, in the manual)
     integer :: nbast !< number of basis functions
     integer, allocatable :: atm(:,:) !< atom information
     integer, allocatable :: bas(:,:) !< shell information
     real*8, allocatable :: env(:) !< double data (coordinates, exponents, coefficients)
  end type cintdata
  
  ! Molecular wavefunction type
  ! Order of the orbitals:
  ! Restricted wavefunctions (wfntyp = wfn_rhf):
  !
  !       occ. (a+b)               virt. (a+b)
  ! | ..................... | ..................... |
  ! 1                     nmoocc                  nmoall
  !
  ! Restricted open wavefunctions (wfntyp = wfn_rohf):
  !
  !       occ. (a+b)           occ.(a)    virt.(a+b)
  ! | ..................... | .........|............|
  ! 1                     nalpha     nmocc        nmoall
  !
  ! Unrestricted wavefunctions (wfntyp = wfn_uhf):
  !
  !    <-- occupied -->        <-- virtual -->
  !     alpha       beta        alpha       beta
  ! | ......... | ......... | ......... | ......... |
  ! 1         nalpha      nmoocc     nmoocc+      nmoall
  !                                nalpha_virt
  ! 
  ! Fractional wavefunctions (wfntyp = wfn_frac): 
  ! 
  ! | ............................................. |
  ! 1                                         nmoall = nmoocc
  ! 
  ! In rhf and uhf wavefunctions, the virtual orbitals (nmoocc to
  ! nmoall) are only available if hasvirtual = .true.
  type molwfn
     logical :: useecp !< this wavefunction comes from a calc with ECPs
     integer :: nmoall !< number of molecular orbitals (occupied and virtual)
     integer :: nmoocc !< number of occupied molecular orbitals
     integer :: nalpha !< number of alpha electrons
     integer :: nalpha_virt !< number of virtual alpha orbitals
     integer :: npri !< number of primitives
     integer :: wfntyp !< type of wavefunction (rhf, uhf, fractional occ)
     logical :: issto !< are the primitives GTOs or STOs?
     logical :: hasvirtual !< are the virtual orbitals known?
     integer :: ixmaxsto(4) !< maximum exponent for x, y, z, and r in STOs
     integer, allocatable :: icenter(:) !< primitive center
     integer, allocatable :: icord(:) !< icenter(icord(1:nprim)) is ordered
     integer, allocatable :: iprilo(:) !< atom i has primitives from iprilo(i) to iprihi(i)
     integer, allocatable :: iprihi(:) !< atom i has primitives from iprilo(i) to iprihi(i)
     integer, allocatable :: itype(:) !< primitive type (see li(:,:) array)
     integer, allocatable :: lmax(:) !< maximum l for each atom
     real*8, allocatable :: dran(:) !< maximum d^2 (GTO) or d (STO) to discard the primitive
     real*8, allocatable :: e(:) !< primitive exponents
     real*8, allocatable :: occ(:) !< MO occupation numbers
     real*8, allocatable :: cmo(:,:) !< MO coefficients
     integer :: nedf !< number of EDFs (electron density functions - core density for ECPs)
     integer, allocatable :: icenter_edf(:) !< EDF centers
     integer, allocatable :: icord_edf(:) !< icenter_edf(icord(1:nedf)) is ordered
     integer, allocatable :: iprilo_edf(:) !< atom i has edf from iprilo(i) to iprihi(i)
     integer, allocatable :: iprihi_edf(:) !< atom i has edf from iprilo(i) to iprihi(i)
     integer, allocatable :: itype_edf(:) !< EDF types
     real*8, allocatable :: dran_edf(:) !< maximum d^2 (GTO) or d (STO) to discard the primitive
     real*8, allocatable :: e_edf(:) !< EDF exponents
     real*8, allocatable :: c_edf(:) !< EDF coefficients
     ! basis set information for libCINT, calculation of molecular integrals
     type(cintdata), allocatable :: cint
     ! structural info
     real*8 :: globalcutoff = 0d0
     real*8, allocatable :: spcutoff(:)
     logical :: isealloc = .false.
     type(environ), pointer :: env
   contains
     procedure :: end => wfn_end !< deallocate all arrays in wfn object
     procedure :: read_wfn !< read wavefunction from a Gaussian wfn file
     procedure :: read_wfx !< read wavefunction from a Gaussian wfx file
     procedure :: read_fchk !< read wavefunction from a Gaussian formatted checkpoint file
     procedure :: read_molden !< read wavefunction from a molden file
     procedure :: rho2 !< calculate the density, derivatives, and other properties
     procedure :: mep !< calculate the molecular electrostatic potential
     procedure :: uslater !< calculate the Slater potential
     procedure :: xhole !< calculate the exchange hole
     procedure :: calculate_mo !< calculate the MO values at a point (driver)
  end type molwfn
  public :: molwfn

  public :: wfn_read_xyz_geometry
  public :: wfn_read_wfn_geometry
  public :: wfn_read_wfx_geometry
  public :: wfn_read_fchk_geometry
  public :: wfn_read_molden_geometry
  public :: wfn_read_log_geometry
  public :: wfn_read_dat_geometry
  public :: wfn_read_pgout_geometry
  public :: wfn_read_orca_geometry

  ! wfn type identifier
  integer, parameter, public :: wfn_rhf = 0
  integer, parameter, public :: wfn_uhf = 1
  integer, parameter, public :: wfn_rohf = 2
  integer, parameter, public :: wfn_frac = 3
  
  interface
     module subroutine wfn_end(f)
       class(molwfn), intent(inout) :: f
     end subroutine wfn_end
     module subroutine wfn_read_xyz_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_xyz_geometry
     module subroutine wfn_read_wfn_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_wfn_geometry
     module subroutine wfn_read_wfx_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_wfx_geometry
     module subroutine wfn_read_fchk_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_fchk_geometry
     module subroutine wfn_read_molden_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_molden_geometry
     module subroutine wfn_read_log_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_log_geometry
     module subroutine wfn_read_dat_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_dat_geometry
     module subroutine wfn_read_pgout_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_pgout_geometry
     module subroutine wfn_read_orca_geometry(file,n,x,z,name,errmsg)
       character*(*), intent(in) :: file
       integer, intent(out) :: n
       real*8, allocatable, intent(inout) :: x(:,:)
       integer, allocatable, intent(inout) :: z(:)
       character*(10), allocatable, intent(inout) :: name(:)
       character(len=:), allocatable, intent(out) :: errmsg
     end subroutine wfn_read_orca_geometry
     module subroutine read_wfn(f,file,env)
       class(molwfn), intent(inout) :: f
       character*(*), intent(in) :: file
       type(environ), intent(in), target :: env
     end subroutine read_wfn
     module subroutine read_wfx(f,file,env)
       class(molwfn), intent(inout) :: f
       character*(*), intent(in) :: file
       type(environ), intent(in), target :: env
     end subroutine read_wfx
     module subroutine read_fchk(f,file,readvirtual,env)
       class(molwfn), intent(inout) :: f
       character*(*), intent(in) :: file
       logical, intent(in) :: readvirtual
       type(environ), intent(in), target :: env
     end subroutine read_fchk
     module subroutine read_molden(f,file,prinorm,readvirtual,env)
       class(molwfn), intent(inout) :: f
       character*(*), intent(in) :: file
       logical, intent(in) :: prinorm
       logical, intent(in) :: readvirtual
       type(environ), intent(in), target :: env
     end subroutine read_molden
     module subroutine rho2(f,xpos,nder,rho,rhoval,grad,gradval,h,hval,gkin,vir,stress,xmo)
       class(molwfn), intent(in) :: f
       real*8, intent(in) :: xpos(3)
       integer, intent(in) :: nder 
       real*8, intent(out) :: rho(3)
       real*8, intent(out) :: rhoval(3)
       real*8, intent(out) :: grad(3,3)
       real*8, intent(out) :: gradval(3,3)
       real*8, intent(out) :: h(3,3,3)
       real*8, intent(out) :: hval(3,3,3)
       real*8, intent(out) :: gkin(3)
       real*8, intent(out) :: vir
       real*8, intent(out) :: stress(3,3)
       real*8, allocatable, intent(out), optional :: xmo(:)
     end subroutine rho2
     module function mep(f,xpos)
       class(molwfn), intent(in) :: f
       real*8, intent(in) :: xpos(3)
       real*8 :: mep
     end function mep
     module subroutine uslater(f,xpos,ux,nheff)
       class(molwfn), intent(in) :: f
       real*8, intent(in) :: xpos(3)
       real*8, intent(out) :: ux
       real*8, intent(out), optional :: nheff
     end subroutine uslater
     module subroutine xhole(f,xpos,xref,xh)
       class(molwfn), intent(in) :: f
       real*8, intent(in) :: xpos(3)
       real*8, intent(in) :: xref(3)
       real*8, intent(out) :: xh
     end subroutine xhole
     module subroutine calculate_mo(f,xpos,phi,fder)
       class(molwfn), intent(in) :: f
       real*8, intent(in) :: xpos(3)
       real*8, intent(out) :: phi
       character*(*), intent(in) :: fder
     end subroutine calculate_mo
  end interface

end module wfn_private
