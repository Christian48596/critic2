! Copyright (c) 2015 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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
!

!> Basic plotting capabilities: contour diagrams, 1d, 2d and 3d representations.
module rhoplot
  implicit none

  private
  
  public :: rhoplot_point
  public :: rhoplot_line
  public :: rhoplot_cube
  public :: rhoplot_plane
  private :: contour
  private :: relief
  private :: colormap
  private :: hallarpuntos
  private :: ordenarpuntos
  private :: linea
  public :: rhoplot_grdvec
  private :: plotvec
  private :: wrtpath
  private :: autochk
  private :: write_fichlabel
  private :: write_fichgnu

  ! contour lines common variables.
  ! npuntos                     number of points in the isoline
  ! xc, yc                      coordinates of the points
  ! pic, pjc                    index of nearest grid values.
  integer, parameter :: nptcorte = 20000
  integer :: npuntos
  real*8  :: xc(nptcorte), yc(nptcorte), pic(nptcorte), pjc(nptcorte)

  ! gradient field walk paths database.
  integer, parameter :: MORIG = 1000
  integer, parameter :: mncritp = 1000
  integer :: norig, grpproj
  integer :: grpatr(MORIG), grpup(MORIG), grpdwn(MORIG)
  real*8  :: grprad1, grprad2, grprad3, grpendpt
  real*8  :: grphcutoff
  real*8  :: grpx(3,MORIG)
  real*8  :: grpcpeps
  real*8  :: r01, r02, a012, sinalfa, cosalfa, cotgalfa
  real*8  :: rp0(3), rp1(3), rp2(3), rp01(3), rp02(3), rpn(4)
  real*8  :: amat(3,3), bmat(3,3)
  real*8  :: scalex, scaley
  integer :: newncriticp
  integer :: newtypcrit(mncritp)
  real*8  :: newcriticp(3,mncritp)
  integer :: cpup(mncritp), cpdn(mncritp)
  integer :: indmax
  logical :: isneg
  real*8 :: RHOP_Hmax = 1d-1

  real*8, parameter  :: epsdis = 1d-4 !< distance cutoff (bohr) for in-plane
  real*8, parameter  :: epsf = 1d-5 !< distance cutoff (cryst) for strict tests
  integer, parameter :: RHOP_Mstep = 4000 !< max. number of gp steps

contains

  ! Calculate properties at a point
  subroutine rhoplot_point(line)
    use fields, only: fieldname_to_idx, goodfield, fused, fields_fcheck, &
       fields_feval, fields_propty
    use crystalmod, only: cr
    use global, only: eval_next, refden, dunit0, iunit
    use arithmetic, only: eval
    use tools_io, only: ferror, faterr, lgetword, equal, getword, &
       isexpression_or_word, uout, string
    use types, only: scalar_value
    use param, only: bohrtoa
    character*(*), intent(in) :: line

    type(scalar_value) :: res
    logical :: ok, doall, iok
    integer :: lp, lp2, i, j, imin, imax
    real*8 :: x0(3), xp(3), rdum
    character(len=:), allocatable :: word, expr

    ! read the point
    lp = 1
    ok = eval_next(x0(1),line,lp)
    ok = ok .and. eval_next(x0(2),line,lp)
    ok = ok .and. eval_next(x0(3),line,lp)
    if (.not. ok) then
       call ferror('critic','wrong POINT command',faterr,line,syntax=.true.)
       return
    end if

    ! read additional options
    doall = .false.
    imin = refden
    imax = refden
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,'all')) then
          doall = .true.
       elseif (equal(word,'field')) then
          lp2 = lp
          word = getword(line,lp)
          imin = fieldname_to_idx(word)
          if (imin < 0) then
             lp = lp2
             ok = isexpression_or_word(expr,line,lp)
             if (.not.ok) then
                call ferror('rhoplot_point','wrong FIELD in POINT',faterr,line,syntax=.true.)
                return
             end if
          else
             if (.not.goodfield(imin)) then
                call ferror('rhoplot_point','field not allocated',faterr,line,syntax=.true.)
                return
             end if
          end if
          imax = imin
       elseif(len_trim(word) < 1) then
          exit
       else
          call ferror('rhoplot_point','Unknown keyword in POINT',faterr,line,syntax=.true.)
          return
       end if
    end do

    if (doall) then
       imin = size(fused)-1
       imax = 0
       do i = 0, size(fused)-1
          if (fused(i)) then
             imin = min(i,imin)
             imax = max(i,imax)
          end if
       end do
    end if
    
    write (uout,'("* POINT ",3(A,2X))') (string(x0(j),'f',decimal=7),j=1,3)
    if (.not.cr%ismolecule) then
       xp = cr%x2c(x0)
       write (uout,'("  Coordinates (bohr): ",3(A,2X))') (string(xp(j),'f',decimal=7),j=1,3)
       write (uout,'("  Coordinates (ang): ",3(A,2X))') (string(xp(j)*bohrtoa,'f',decimal=7),j=1,3)
    else
       xp = x0 / dunit0(iunit) - cr%molx0
       x0 = cr%c2x(xp)
    endif
    if (imin > -1) then
       do i = imin, imax
          if (.not.goodfield(i)) cycle
          write (uout,'("+ Field: ",A)') string(i)
          call fields_propty(i,x0,res,.true.,.false.)
       end do
    else
       rdum = eval(expr,.true.,iok,xp,fields_fcheck,fields_feval)
       write (uout,'("  Expression (",A,"): ",A)') string(expr), string(rdum,'e',decimal=9)
    endif
    write (uout,*)

  end subroutine rhoplot_point

  ! Calculate properties on a line
  subroutine rhoplot_line(line)
    use fields, only: fieldname_to_idx, goodfield, f, fields_feval, fields_fcheck,&
       grd
    use crystalmod, only: cr
    use global, only: eval_next, refden, dunit0, iunit
    use arithmetic, only: eval
    use tools_io, only: ferror, faterr, lgetword, equal, getword, equal,&
       isexpression_or_word, fopen_write, uout, string, fclose
    use tools_math, only: norm
    use types, only: scalar_value_noalloc
    character*(*), intent(in) :: line

    integer :: lp, lp2, nti, id, luout, np
    real*8 :: x0(3), x1(3), xp(3), dist, rhopt, lappt, xout(3)
    character(len=:), allocatable :: word, outfile, prop, expr
    type(scalar_value_noalloc) :: res
    logical :: ok, iok
    integer :: i
    real*8, allocatable :: rhoout(:), lapout(:)

    ! read the points
    lp = 1
    ok = eval_next(x0(1),line,lp)
    ok = ok .and. eval_next(x0(2),line,lp)
    ok = ok .and. eval_next(x0(3),line,lp)
    ok = ok .and. eval_next(x1(1),line,lp)
    ok = ok .and. eval_next(x1(2),line,lp)
    ok = ok .and. eval_next(x1(3),line,lp)
    ok = ok .and. eval_next(np,line,lp)
    if (.not. ok) then
       call ferror('critic','wrong LINE order',faterr,line,syntax=.true.)
       return
    end if

    ! at least two points
    np = max(np,2)

    ! read additional options
    nti = 0
    prop = ""
    id = refden
    outfile = "" 
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,'file')) then
          outfile = getword(line,lp)
          if (len_trim(outfile) < 1) then
             call ferror('rhoplot_line','file name not found',faterr,line,syntax=.true.)
             return
          end if
       else if (equal(word,'field')) then
          lp2 = lp
          word = getword(line,lp)
          id = fieldname_to_idx(word)
          if (id < 0) then
             lp = lp2
             ok = isexpression_or_word(expr,line,lp)
             if (.not.ok) then
                call ferror('rhoplot_line','wrong FIELD in LINE',faterr,line,syntax=.true.)
                return
             end if
          else
             if (.not.goodfield(id)) then
                call ferror('rhoplot_line','field not allocated',faterr,line,syntax=.true.)
                return
             end if
          end if
       elseif (equal(word,'gx')) then
          nti = 1
          prop = word
       else if (equal(word,'gy')) then
          nti = 2
          prop = word
       else if (equal(word,'gz')) then
          nti = 3
          prop = word
       else if (equal(word,'gmod')) then
          nti = 4
          prop = word
       else if (equal(word,'hxx')) then
          nti = 5
          prop = word
       else if (equal(word,'hxy') .or. equal(word,'hyx')) then
          nti = 6
          prop = word
       else if (equal(word,'hxz') .or. equal(word,'hzx')) then
          nti = 7
          prop = word
       else if (equal(word,'hyy')) then
          nti = 8
          prop = word
       else if (equal(word,'hyz') .or. equal(word,'hzy')) then
          nti = 9
          prop = word
       else if (equal(word,'hzz')) then
          nti = 10
          prop = word
       else if (equal(word,'lap')) then
          nti = 11
          prop = word
       else if (len_trim(word) > 0) then
          call ferror('rhoplot_line','Unknown keyword in LINE',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    ! open the output
    if (len_trim(outfile) > 0) then
       luout = fopen_write(outfile)
    else
       luout = uout
       write (uout,'("* LINE ")')
    end if

    ! header
    write (luout,'("# Field values (f) along a line (d = distance).")')
    write (luout,'("#",1x,4a15,1p,2a20,0p)') "x","y","z","d","f",string(prop)

    ! calculate the line
    if (.not.cr%ismolecule) then
       x0 = cr%x2c(x0)
       x1 = cr%x2c(x1)
    else
       x0 = x0 / dunit0(iunit) - cr%molx0
       x1 = x1 / dunit0(iunit) - cr%molx0
    endif
    allocate(rhoout(np),lapout(np))
    lapout = 0d0

    !$omp parallel do private (xp,dist,res,iok,rhopt,lappt) schedule(dynamic)
    do i=1,np
       xp = x0 + (x1 - x0) * real(i-1,8) / real(np-1,8)
       if (id >= 0) then
          if (nti == 0) then
             call grd(f(id),xp,0,.not.cr%ismolecule,res0_noalloc=res)
          elseif (nti >= 1 .and. nti <= 4) then
             call grd(f(id),xp,1,.not.cr%ismolecule,res0_noalloc=res)
          else
             call grd(f(id),xp,2,.not.cr%ismolecule,res0_noalloc=res)
          end if

          rhopt = res%f
          select case(nti)
          case (0)
             lappt = rhopt
          case (1)
             lappt = res%gf(1)
          case (2)
             lappt = res%gf(2)
          case (3)
             lappt = res%gf(3)
          case (4)
             lappt = res%gfmod
          case (5)
             lappt = res%hf(1,1)
          case (6)
             lappt = res%hf(1,2)
          case (7)
             lappt = res%hf(1,3)
          case (8)
             lappt = res%hf(2,2)
          case (9)
             lappt = res%hf(2,3)
          case (10)
             lappt = res%hf(3,3)
          case (11)
             lappt = res%del2f
          end select
       else
          rhopt = eval(expr,.true.,iok,xp,fields_fcheck,fields_feval)
          lappt = rhopt
       end if

       !$omp critical (iowrite)
       rhoout(i) = rhopt
       lapout(i) = lappt
       !$omp end critical (iowrite)
    enddo
    !$omp end parallel do

    ! write the line to output
    do i = 1, np
       xp = x0 + (x1 - x0) * real(i-1,8) / real(np-1,8)
       dist = norm(xp-x0) * dunit0(iunit)
       if (.not.cr%ismolecule) then
          xout = cr%c2x(xp)
       else
          xout = (xp + cr%molx0) * dunit0(iunit)
       end if
       if (nti == 0) then
          write (luout,'(1x,4(f15.10,x),1p,1(e18.10,x),0p)') &
             xout, dist, rhoout(i)
       else
          write (luout,'(1x,4(f15.10,x),1p,2(e18.10,x),0p)') &
             xout, dist, rhoout(i), lapout(i)
       end if
    end do
    write (luout,*)
    if (len_trim(outfile) > 0) then
       call fclose(luout)
       write (uout,'("* LINE written to file: ",A/)') string(outfile)
    end if

    ! clean up
    deallocate(rhoout,lapout)

  end subroutine rhoplot_line

  ! Calculate properties on a 3d cube
  subroutine rhoplot_cube(line)
    use grid_tools, only: grid_rhoat
    use fields, only: fieldname_to_idx, goodfield, f, type_grid, fields_fcheck,&
       fields_feval, writegrid_cube, writegrid_vasp, grd
    use crystalmod, only: cr
    use global, only: eval_next, dunit0, iunit, refden, fileroot
    use arithmetic, only: eval
    use tools_math, only: norm
    use tools_io, only: lgetword, faterr, ferror, equal, getword, &
       isexpression_or_word, uout, string
    use types, only: scalar_value_noalloc, field
    use param, only: eye
    character*(*), intent(in) :: line

    integer :: lp, nti, id, nn(3)
    real*8 :: x0(3), x1(3), xp(3), lappt
    real*8 :: rgr, dd(3), xd(3,3)
    integer :: lp2
    character(len=:), allocatable :: word, outfile, prop, expr, wext1
    type(scalar_value_noalloc) :: res
    logical :: ok, iok
    integer :: ix, iy, iz, i
    real*8, allocatable :: lf(:,:,:)
    logical :: dogrid, useexpr, iscube, doheader
    type(field) :: faux

    ! read the points
    lp = 1
    lp2 = 1
    dogrid = .false.
    doheader = .false.
    word = lgetword(line,lp)
    ok = eval_next(x0(1),word,lp2)
    if (ok) then
       ! read initial and final points
       ok = ok .and. eval_next(x0(2),line,lp)
       ok = ok .and. eval_next(x0(3),line,lp)
       ok = ok .and. eval_next(x1(1),line,lp)
       ok = ok .and. eval_next(x1(2),line,lp)
       ok = ok .and. eval_next(x1(3),line,lp)
       if (.not. ok) then
          call ferror('rhoplot_cube','wrong CUBE syntax',faterr,line,syntax=.true.)
          return
       end if

       ! If it is a molecule, that was Cartesian
       if (cr%ismolecule) then
          x0 = cr%c2x(x0 / dunit0(iunit) - cr%molx0)
          x1 = cr%c2x(x1 / dunit0(iunit) - cr%molx0)
       endif

       ! cubic cube
       xd = 0d0
       do i = 1, 3
          xd(i,i) = x1(i) - x0(i)
       end do
    elseif (equal(word,'cell')) then
       ! whole cell, maybe non-cubic
       xd = eye
       x0 = 0d0
    elseif (equal(word,'grid')) then
       dogrid = .true.
       xd = eye
       x0 = 0d0
    endif

    ! calculate the distances
    x0 = cr%x2c(x0)
    do i = 1, 3
       xd(:,i) = cr%x2c(xd(:,i))
       dd(i) = norm(xd(:,i))
    end do

    if (.not.dogrid) then
       ! read number of points or grid resolution
       lp2 = lp
       ok = eval_next(nn(1),line,lp)
       ok = ok .and. eval_next(nn(2),line,lp)
       ok = ok .and. eval_next(nn(3),line,lp)
       if (.not. ok) then
          lp = lp2
          ok = eval_next(rgr,line,lp)
          if (.not. ok) then
             call ferror('rhoplot_cube','wrong CUBE syntax',faterr,line,syntax=.true.)
             return
          end if
          nn = nint(dd / rgr) + 1
       else
          do i = 1, 3
             nn(i) = max(nn(i),2)
          end do
       end if
    end if

    ! read additional options
    nti = 0
    prop = "f"
    id = refden
    useexpr = .false.
    iscube = .true.
    outfile = trim(fileroot) // ".cube" 
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,'file')) then
          outfile = getword(line,lp)
          if (len_trim(outfile) < 1) then
             call ferror('rhoplot_cube','file name not found',faterr,line,syntax=.true.)
             return
          end if
          wext1 = outfile(index(outfile,'.',.true.)+1:)
          iscube = (equal(wext1,'cube')) 
       else if (equal(word,'field')) then
          lp2 = lp
          word = getword(line,lp)
          id = fieldname_to_idx(word)
          if (id < 0) then
             lp = lp2
             ok = isexpression_or_word(expr,line,lp)
             useexpr = .true.
             if (.not.ok) then
                call ferror('rhoplot_cube','wrong FIELD in CUBE',faterr,line,syntax=.true.)
                return
             end if
          else
             if (.not.goodfield(id)) then
                call ferror('rhoplot_cube','field not allocated',faterr,line,syntax=.true.)
                return
             end if
          end if
       else if (equal(word,'header')) then
          doheader = .true.
       else if (equal(word,'f')) then
          nti = 0
          prop = word
       elseif (equal(word,'gx')) then
          nti = 1
          prop = word
       else if (equal(word,'gy')) then
          nti = 2
          prop = word
       else if (equal(word,'gz')) then
          nti = 3
          prop = word
       else if (equal(word,'gmod')) then
          nti = 4
          prop = word
       else if (equal(word,'hxx')) then
          nti = 5
          prop = word
       else if (equal(word,'hxy') .or. equal(word,'hyx')) then
          nti = 6
          prop = word
       else if (equal(word,'hxz') .or. equal(word,'hzx')) then
          nti = 7
          prop = word
       else if (equal(word,'hyy')) then
          nti = 8
          prop = word
       else if (equal(word,'hyz') .or. equal(word,'hzy')) then
          nti = 9
          prop = word
       else if (equal(word,'hzz')) then
          nti = 10
          prop = word
       else if (equal(word,'lap')) then
          nti = 11
          prop = word
       else if (len_trim(word) > 0) then
          call ferror('rhoplot_cube','Unknown keyword in CUBE',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    ! step sizes
    if (dogrid) then
       ok = (id > -1)
       if (ok) ok = ok .and. (f(id)%type == type_grid)
       if (.not.ok) then
          call ferror('rhoplot_cube','CUBE GRID can only be used with grid fields',faterr,syntax=.true.)
          return
       end if
       nn = f(id)%n
    end if
    do i = 1, 3
       xd(:,i) = xd(:,i) / real(nn(i),8)
    end do

    ! write cube header
    write (uout,'("* CUBE written to file: ",A/)') string(outfile)
    if (doheader) then
       if (iscube) then
          call writegrid_cube(cr,f(id)%f,outfile,.true.,xd,x0+cr%molx0)
       else
          call writegrid_vasp(cr,f(id)%f,outfile,.true.)
       endif
       return
    end if

    ! calculate properties
    if (dogrid) then
       if (f(id)%type /= type_grid) then
          call ferror('rhoplot_cube','grid can be used only with a grid field',faterr,syntax=.true.)
          return
       end if
       if (f(id)%usecore) then
          faux = f(id)
          call grid_rhoat(f(id),faux,3)
          faux%f = faux%f + f(id)%f
       else
          faux = f(id)
       end if
       if (iscube) then
          call writegrid_cube(cr,faux%f,outfile,.false.,xd,x0+cr%molx0)
       else
          call writegrid_vasp(cr,faux%f,outfile,.false.)
       end if
    else
       allocate(lf(nn(1),nn(2),nn(3)))
       !$omp parallel do private (xp,res,lappt) schedule(dynamic)
       do iz = 0, nn(3)-1
          do iy = 0, nn(2)-1
             do ix = 0, nn(1)-1
                xp = x0 + real(ix,8) * xd(:,1) + real(iy,8) * xd(:,2) &
                   + real(iz,8) * xd(:,3)

                if (.not.useexpr) then
                   call grd(f(id),xp,2,.not.cr%ismolecule,res0_noalloc=res)
                   select case(nti)
                   case (0)
                      lappt = res%f
                   case (1)
                      lappt = res%gf(1)
                   case (2)
                      lappt = res%gf(2)
                   case (3)
                      lappt = res%gf(3)
                   case (4)
                      lappt = res%gfmod
                   case (5)
                      lappt = res%hf(1,1)
                   case (6)
                      lappt = res%hf(1,2)
                   case (7)
                      lappt = res%hf(1,3)
                   case (8)
                      lappt = res%hf(2,2)
                   case (9)
                      lappt = res%hf(2,3)
                   case (10)
                      lappt = res%hf(3,3)
                   case (11)
                      lappt = res%del2f
                   end select
                else
                   lappt = eval(expr,.true.,iok,xp,fields_fcheck,fields_feval)
                end if
                !$omp critical (fieldwrite)
                lf(ix+1,iy+1,iz+1) = lappt
                !$omp end critical (fieldwrite)
             end do
          end do
       end do
       !$omp end parallel do
       ! cube body
       if (iscube) then
          call writegrid_cube(cr,lf,outfile,.false.,xd,x0+cr%molx0)
       else
          call writegrid_vasp(cr,lf,outfile,.false.)
       endif
       deallocate(lf)
    end if
    
  end subroutine rhoplot_cube

  !> Calculate properties on a plane.
  subroutine rhoplot_plane(line)
    use fields, only: fieldname_to_idx, goodfield, f, grd, fields_fcheck, &
       fields_feval
    use crystalmod, only: cr
    use global, only: eval_next, dunit0, iunit, refden, fileroot
    use arithmetic, only: eval
    use tools_io, only: ferror, faterr, lgetword, equal, getword, &
       isexpression_or_word, fopen_write, uout, string, fclose
    use tools_math, only: norm, plane_scale_extend, assign_ziso, niso_manual,&
       niso_lin, niso_log, niso_atan, niso_bader
    use types, only: scalar_value_noalloc, realloc
    character*(*), intent(in) :: line

    integer :: lp2, lp, nti, id, luout, nx, ny, niso_type, niso, nn
    real*8 :: x0(3), x1(3), x2(3), xp(3), du, dv, rhopt
    real*8 :: uu(3), vv(3), lin0, lin1
    real*8 :: sx, sy, zx0, zx1, zy0, zy1, zmin, zmax, rdum
    logical :: docontour, dorelief, docolormap
    character(len=:), allocatable :: word, outfile, root0, expr
    type(scalar_value_noalloc) :: res
    logical :: ok, iok
    integer :: ix, iy, cmopt, nder
    real*8, allocatable :: ff(:,:), ziso(:)

    ! read the points
    lp = 1
    ok = eval_next(x0(1),line,lp)
    ok = ok .and. eval_next(x0(2),line,lp)
    ok = ok .and. eval_next(x0(3),line,lp)
    ok = ok .and. eval_next(x1(1),line,lp)
    ok = ok .and. eval_next(x1(2),line,lp)
    ok = ok .and. eval_next(x1(3),line,lp)
    ok = ok .and. eval_next(x2(1),line,lp)
    ok = ok .and. eval_next(x2(2),line,lp)
    ok = ok .and. eval_next(x2(3),line,lp)
    if (.not. ok) then
       call ferror('rhoplot_plane','Wrong PLANE command: x0, x1, x2',faterr,line,syntax=.true.)
       return
    end if
    if (cr%ismolecule) then
       x0 = cr%c2x(x0 / dunit0(iunit) - cr%molx0)
       x1 = cr%c2x(x1 / dunit0(iunit) - cr%molx0)
       x2 = cr%c2x(x2 / dunit0(iunit) - cr%molx0)
    endif

    ok = eval_next(nx,line,lp)
    ok = ok .and. eval_next(ny,line,lp)
    if (.not. ok) then
       call ferror('rhoplot_plane','Wrong PLANE command: nx and ny',faterr,line,syntax=.true.)
       return
    end if

    ! at least two points 
    nx = max(nx,2)
    ny = max(ny,2)

    ! read additional options
    lin0 = 0d0
    lin1 = 1d0
    sx = 1d0
    sy = 1d0
    zx0 = 0d0
    zx1 = 0d0
    zy0 = 0d0
    zy1 = 0d0
    nti = 0
    docontour = .false.
    dorelief = .false.
    docolormap = .false.
    id = refden
    outfile = trim(fileroot) // "_plane.dat" 
    do while (.true.)
       word = lgetword(line,lp)
       if (equal(word,'file')) then
          outfile = getword(line,lp)
          if (len_trim(outfile) < 1) then
             call ferror('rhoplot_plane','file name not found',faterr,line,syntax=.true.)
             return
          end if
       else if (equal(word,'field')) then
          lp2 = lp
          word = getword(line,lp)
          id = fieldname_to_idx(word)
          if (id < 0) then
             lp = lp2
             ok = isexpression_or_word(expr,line,lp)
             if (.not.ok) then
                call ferror('rhoplot_point','wrong FIELD in LINE',faterr,line,syntax=.true.)
                return
             end if
          else
             if (.not.goodfield(id)) then
                call ferror('rhoplot_plane','field not allocated',faterr,line,syntax=.true.)
                return
             end if
          end if
       elseif (equal(word,'scale')) then
          ok = eval_next(sx,line,lp)
          ok = ok .and. eval_next(sy,line,lp)
          if (.not. ok) then
             call ferror('rhoplot_plane','wrong SCALE keyword in PLANE',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,'extendx')) then
          ok = eval_next(zx0,line,lp)
          ok = ok .and. eval_next(zx1,line,lp)
          if (.not. ok) then
             call ferror('rhoplot_plane','wrong EXTENDX keyword in PLANE',faterr,line,syntax=.true.)
             return
          end if
          zx0 = zx0 / dunit0(iunit)
          zx1 = zx1 / dunit0(iunit)
       elseif (equal(word,'extendy')) then
          ok = eval_next(zy0,line,lp)
          ok = ok .and. eval_next(zy1,line,lp)
          if (.not. ok) then
             call ferror('rhoplot_plane','wrong EXTENDY keyword in PLANE',faterr,line,syntax=.true.)
             return
          end if
          zy0 = zy0 / dunit0(iunit)
          zy1 = zy1 / dunit0(iunit)
       else if (equal(word,'relief')) then
          dorelief = .true.
          zmin = -1d0
          zmax = 1d0
          ok = eval_next(zmin,line,lp)
          ok = ok .and. eval_next(zmax,line,lp)
          if (.not.ok) then
             call ferror('rhoplot_plane','wrong levels in RELIEF',faterr,line,syntax=.true.)
             return
          end if
       else if (equal(word,'contour')) then
          lp2 = lp
          word = lgetword(line,lp)
          docontour = .true.
          if (equal(word,'lin')) then
             niso_type = niso_lin
          elseif (equal(word,'log')) then
             niso_type = niso_log
          elseif (equal(word,'atan')) then
             niso_type = niso_atan
          elseif (equal(word,'bader')) then
             niso_type = niso_bader
          else
             niso_type = niso_manual
             lp = lp2
             ok = eval_next(rdum,line,lp)
             if (ok) then
                niso = 1
                if (allocated(ziso)) deallocate(ziso)
                allocate(ziso(1))
                ziso(1) = rdum
                do while (.true.)
                   lp2 = lp
                   ok = eval_next(rdum,line,lp)
                   if (.not.ok) exit
                   niso = niso + 1
                   if (niso > size(ziso,1)) call realloc(ziso,2*niso)
                   ziso(niso) = rdum
                end do
                call realloc(ziso,niso)
             else
                call ferror("rhoplot_plane","Unknown contour keyword",faterr,line,syntax=.true.)
             end if
          end if
          if (niso_type == niso_lin .or. niso_type == niso_log .or.&
              niso_type == niso_atan) then
             ok = eval_next(niso,line,lp)
             if (.not.ok) then
                call ferror("rhoplot_plane","number of isovalues not found",faterr,line,syntax=.true.)
                return
             end if
             if (niso_type == niso_lin) then
                ok = eval_next(lin0,line,lp)
                ok = ok .and. eval_next(lin1,line,lp)
                if (.not.ok) then
                   call ferror("rhoplot_plane","initial and final isovalues not found",faterr,line,syntax=.true.)
                   return
                end if
             end if
          end if
       else if (equal(word,'colormap')) then
          docolormap = .true.
          lp2 = lp
          word = lgetword(line,lp)
          cmopt = 0
          if (equal(word,'log')) then
             cmopt = 1
          elseif (equal(word,'atan')) then
             cmopt = 2
          else
             lp = lp2
          end if
       elseif (equal(word,'f')) then
          nti = 0
       else if (equal(word,'gx')) then
          nti = 1
       else if (equal(word,'gy')) then
          nti = 2
       else if (equal(word,'gz')) then
          nti = 3
       else if (equal(word,'gmod')) then
          nti = 4
       else if (equal(word,'hxx')) then
          nti = 5
       else if (equal(word,'hxy') .or. equal(word,'hyx')) then
          nti = 6
       else if (equal(word,'hxz') .or. equal(word,'hzx')) then
          nti = 7
       else if (equal(word,'hyy')) then
          nti = 8
       else if (equal(word,'hyz') .or. equal(word,'hzy')) then
          nti = 9
       else if (equal(word,'hzz')) then
          nti = 10
       else if (equal(word,'lap')) then
          nti = 11
       else if (len_trim(word) > 0) then
          call ferror('rhoplot_plane','Unknown keyword in PLANE',faterr,line,syntax=.true.)
          return
       else
          exit
       end if
    end do

    ! root file name
    nn = index(outfile,".",.true.)
    if (nn == 0) nn = len(trim(outfile)) + 1
    root0 = outfile(1:nn-1)

    ! Transform to Cartesian, extend and scale, and set up the plane
    ! vectors.
    x0 = cr%x2c(x0)
    x1 = cr%x2c(x1)
    x2 = cr%x2c(x2)
    call plane_scale_extend(x0,x1,x2,sx,sy,zx0,zx1,zy0,zy1)
    uu = (x1-x0) / real(nx-1,8)
    du = norm(uu)
    vv = (x2-x0) / real(ny-1,8)
    dv = norm(vv)

    ! allocate space for field values on the plane
    allocate(ff(nx,ny))
    if (nti == 0) then
       nder = 0
    elseif (nti >= 1 .and. nti <= 4) then
       nder = 1 
    else
       nder = 2
    end if

    !$omp parallel do private (xp,res,rhopt,iok) schedule(dynamic)
    do ix = 1, nx
       do iy = 1, ny
          xp = x0 + real(ix-1,8) * uu + real(iy-1,8) * vv

          if (id >= 0) then
             call grd(f(id),xp,nder,.not.cr%ismolecule,res0_noalloc=res)
             select case(nti)
             case (0)
                rhopt = res%f
             case (1)
                rhopt = res%gf(1)
             case (2)
                rhopt = res%gf(2)
             case (3)
                rhopt = res%gf(3)
             case (4)
                rhopt = res%gfmod
             case (5)
                rhopt = res%hf(1,1)
             case (6)
                rhopt = res%hf(1,2)
             case (7)
                rhopt = res%hf(1,3)
             case (8)
                rhopt = res%hf(2,2)
             case (9)
                rhopt = res%hf(2,3)
             case (10)
                rhopt = res%hf(3,3)
             case (11)
                rhopt = res%del2f
             end select
          else
             rhopt = eval(expr,.true.,iok,xp,fields_fcheck,fields_feval)
          endif
          !$omp critical (write)
          ff(ix,iy) = rhopt
          !$omp end critical (write)
       end do
    end do
    !$omp end parallel do

    ! open the output
    if (len_trim(outfile) > 0) then
       luout = fopen_write(outfile)
    else
       luout = uout
       write (uout,'("* PLANE ")')
    end if

    ! header
    write (luout,'("# Field values (and derivatives) on a plane")')
    write (luout,'("# x y z u v f ")')

    x0 = cr%c2x(x0)
    x1 = cr%c2x(x1)
    x2 = cr%c2x(x2)
    uu = cr%c2x(uu)
    vv = cr%c2x(vv)
    do ix = 1, nx
       do iy = 1, ny
          xp = x0 + real(ix-1,8) * uu + real(iy-1,8) * vv
          xp = (cr%x2c(xp) + cr%molx0) * dunit0(iunit)
          write (luout,'(1x,5(f15.10,x),1p,1(e18.10,x),0p)') &
             xp, real(ix-1,8)*du, real(iy-1,8)*dv, ff(ix,iy)
       end do
       write (luout,*)
    end do

    ! contour/relief/colormap plots
    if (docontour) then
       call assign_ziso(niso_type,niso,ziso,lin0,lin1,maxval(ff),minval(ff))
       call contour(ff,x0,x1,x2,nx,ny,niso,ziso,root0,.true.,.true.)
    end if
    if (dorelief) call relief(root0,string(outfile),zmin,zmax)
    if (docolormap) call colormap(root0,string(outfile),cmopt)

    if (len_trim(outfile) > 0) then
       call fclose(luout)
       write (uout,'("* PLANE written to file: ",A)') string(outfile)
       write (uout,*)
    end if

    if (allocated(ziso)) deallocate(ziso)
    deallocate(ff)

  end subroutine rhoplot_plane

  !> Contour plots using the 2d-field ff, defined on a plane
  !> determined by poitns r0, r1, r2 (crystallographic coords.). The
  !> number of points in each direction is nx and ny. ziso(1:niso) is the
  !> array contaiing the contour levels. rootname is the root for all
  !> the files generated (.iso, .neg.iso, -grd.dat, -label.gnu,
  !> .gnu). If dolabels, write the labels file. If dognu, write the
  !> gnu file.
  subroutine contour(ff,r0,r1,r2,nx,ny,niso,ziso,rootname,dognu,dolabels)
    use crystalmod, only: cr
    use tools_io, only: fopen_write, uout, string, faterr, ferror, fclose
    use tools_math, only: norm, cross, det, matinv
    integer, intent(in) :: nx, ny
    real*8, intent(in) :: ff(nx,ny)
    real*8, intent(in) :: r0(3), r1(3), r2(3)
    integer, intent(in) :: niso
    real*8, intent(in) :: ziso(niso)
    character*(*), intent(in) :: rootname
    logical, intent(in) :: dognu, dolabels

    character(len=:), allocatable :: root0, fichiso, fichiso1, fichgnu
    integer :: lud, lud1
    integer :: i, j
    real*8 :: du, dv, r012, ua, va, ub, vc
    real*8, allocatable :: x(:), y(:)

    ! set rootname
    root0 = rootname

    ! name files
    fichgnu = trim(root0) // '-contour.gnu' 
    fichiso = trim(root0) // '.iso' 
    fichiso1 = trim(root0) // '.neg.iso' 

    ! connect units for writing.
    lud = fopen_write(fichiso)
    lud1 = fopen_write(fichiso1)

    write (uout,'("* Name of the contour lines file: ",a)') string(fichiso)
    write (uout,'("* Name of the negative contour lines file: ",a)') string(fichiso1)

    ! geometry
    rp0 = cr%x2c(r0)
    rp1 = cr%x2c(r1)
    rp2 = cr%x2c(r2)
    rp01 = rp1 - rp0
    rp02 = rp2 - rp0
    r01 = norm(rp01)
    r02 = norm(rp02)
    du = r01 / real(nx-1,8)
    dv = r02 / real(ny-1,8)
    r012 = dot_product(rp01,rp02)
    cosalfa = r012/r01/r02
    sinalfa = sqrt(max(1-cosalfa**2,0d0))

    indmax = nint(max(maxval(abs(r0)),maxval(abs(r1)),maxval(abs(r2))))

    ! normal vector and plane equation
    rpn(1:3) = cross(rp01,rp02)
    rpn(4) = -dot_product(rpn(1:3),rp0)
    rpn = rpn / (r01*r02)

    ! plane to cartesian
    amat(:,1) = rp01
    amat(:,2) = rp02
    amat(:,3) = rpn(1:3)

    ! cartesian to plane
    if (abs(det(amat)) < 1d-15) &
       call ferror('contour','Error in the input plane: singular matrix',faterr)
    bmat = matinv(amat)

    ! define plane limits
    ua = 0d0
    ub = r01
    va = 0d0
    vc = r02

    ! calculate grid in each direction
    isneg = minval(ff) < 0d0
    allocate(x(nx))
    allocate(y(ny))
    do i = 1, nx
       do j = 1, ny
          x(i) = ua + (i-1) * (ub-ua) / real(nx-1,8)
          y(j) = va + (j-1) * (vc-va) / real(ny-1,8)
       end do
    end do

    do i = 1, niso
       call hallarpuntos (ff,ziso(i),x,y,nx,ny)
       if (ziso(i).gt.0) then
          call ordenarpuntos (lud,cosalfa,ziso(i))
       else
          call ordenarpuntos (lud1,cosalfa,ziso(i))
       endif
    enddo
    call fclose(lud)
    call fclose(lud1)

    if (dolabels) call write_fichlabel(root0)
    if (dognu) call write_fichgnu(root0,dolabels,.true.,.false.)
    if (allocated(x)) deallocate(x)
    if (allocated(y)) deallocate(y)
    
  end subroutine contour

  !> Write a gnuplot template for the relief plot
  subroutine relief(rootname,outfile,zmin,zmax)
    use tools_io, only: fopen_write, uout, string, fclose
    real*8, intent(in) :: zmin, zmax
    character*(*), intent(in) :: rootname, outfile

    character(len=:), allocatable :: file
    integer :: lu
    
    ! file name
    file = trim(rootname) // '-relief.gnu'

    ! connect unit
    lu = fopen_write(file)
    write (uout,'("* Gnuplot file (relief): ",a)') string(file)

    write (lu,'("set terminal pdfcairo")')
    write (lu,'("set output """,A,"-relief.pdf""")') rootname
    write (lu,'("set encoding iso_8859_1")')
    write (lu,'("")')
    write (lu,'("set style line 1 lt 1 lc rgb ""#000000"" ")')
    write (lu,'("")')
    write (lu,'("# Define the zrange and the capping functions")')
    write (lu,'("zmin = ",A)') string(zmin,'e',12,5)
    write (lu,'("zmax = ",A)') string(zmax,'e',12,5)
    write (lu,'("stats """,A,""" u 6 nooutput")') outfile
    write (lu,'("min(x) = (x<zmin)?min=x:zmin")')
    write (lu,'("max(x) = (x>zmax)?max=zmax:x")')
    write (lu,'("set zrange [(zmin<STATS_min)?STATS_min:zmin:(zmax>STATS_max)?STATS_max:zmax]")')
    write (lu,'("")')
    write (lu,'("# tics, etc")')
    write (lu,'("unset colorbox")')
    write (lu,'("unset title")')
    write (lu,'("set format x ""%.1f""")')
    write (lu,'("set format y ""%.1f""")')
    write (lu,'("")')
    write (lu,'("# Surface definition")')
    write (lu,'("set pm3d depthorder hidden3d 1")')
    write (lu,'("set hidden3d")')
    write (lu,'("set style fill transparent solid 0.7")')
    write (lu,'("set palette rgb 9,9,3")')
    write (lu,'("set view 60,45")')
    write (lu,'("set size ratio -1")')
    write (lu,'("")')
    write (lu,'("splot """,A,""" u 4:5:(max($6)) ls 1 w pm3d notitle")') outfile

    ! wrap up
    call fclose(lu)

  end subroutine relief

  !> Write a gnuplot template for the color map plot
  subroutine colormap(rootname,outfile,cmopt)
    use tools_io, only: fopen_write, uout, string, fclose
    character*(*), intent(in) :: rootname, outfile
    integer, intent(in) :: cmopt

    character(len=:), allocatable :: file
    integer :: lu
    
    ! file name
    file = trim(rootname) // '-colormap.gnu'

    ! connect unit
    lu = fopen_write(file)
    write (uout,'("* Gnuplot file (colormap): ",a)') string(file)

    write (lu,'("set encoding iso_8859_1")')
    write (lu,'("set terminal postscript eps color enhanced ""Helvetica""")')
    write (lu,'("set output """,A,"-colormap.eps""")') rootname
    write (lu,'("")')
    write (lu,'("# line styles")')
    write (lu,'("set style line 1 lt 1 lw 1 lc rgb ""#000000""")')
    write (lu,'("set style line 2 lt 1 lw 1 lc rgb ""#000000""")')
    write (lu,'("")')
    write (lu,'("# title, key, size")')
    write (lu,'("unset title")')
    write (lu,'("unset key")')
    write (lu,'("set size ratio -1")')
    write (lu,'("")')
    write (lu,'("# set pm3d at b map interpolate 5,5")')
    write (lu,'("set pm3d at b map")')
    write (lu,'("")')
    write (lu,'("# tics")')
    write (lu,'("set cbtics")')
    write (lu,'("")')
    write (lu,'("# color schemes")')
    write (lu,'("set palette defined ( 0 ""red"", 1 ""white"", 2 ""green"" ) ")')
    write (lu,'("")')
    write (lu,'("# set contours")')
    write (lu,'("unset clabel")')
    write (lu,'("set contour base")')
    write (lu,'("set cntrparam bspline")')
    write (lu,'("# set cntrparam levels incremental -min,step,max")')
    write (lu,'("")')
    if (cmopt == 1) then
       write (lu,'("splot """,A,""" u 1:2:(log(abs($6))) ls 1 w pm3d notitle")') outfile
    elseif (cmopt == 2) then
       write (lu,'("splot """,A,""" u 1:2:(2/pi*atan($6)) ls 1 w pm3d notitle")') outfile
    else
       write (lu,'("splot """,A,""" u 1:2:6 ls 1 w pm3d notitle")') outfile
    end if

    ! wrap up
    call fclose(lu)

  end subroutine colormap

  !> Find contour with value = zc on a surface given by a grid.
  !> uses linear interpolation.
  subroutine hallarpuntos(ff,zc,x,y,nx,ny)
    use param, only: zero
    integer, intent(in) :: nx, ny
    real*8, intent(in) :: ff(nx,ny)
    real*8, intent(in) :: zc
    real*8, intent(in) :: x(:), y(:)

    integer :: i, j
    real*8 :: xa, ya, za, xb, yb, zb
    real*8 :: zazc, zbzc

    ! initialize
    npuntos = 0

    ! run over columns
    do i = 1, nx
       xa = x(i)
       ya = y(1)
       za = ff(i,1)
       zazc = za-zc

       ! check if it is an intersection
       if (zazc.eq.zero) then
          npuntos = npuntos+1
          if (npuntos.gt.size(xc)) then
             return
          end if
          xc(npuntos) = xa
          yc(npuntos) = ya
          pic(npuntos) = i
          pjc(npuntos) = 1d0
       endif

       do j = 2,ny
          xb = x(i)
          yb = y(j)
          zb = ff(i,j)
          zbzc = zb-zc

          ! sign changed, interpolate and write a point
          if ((zazc*zbzc).lt.zero) then
             npuntos = npuntos+1
             if (npuntos.gt.size(xc)) then
                return
             end if
             xc(npuntos) = xb
             yc(npuntos) = ya-zazc*(yb-ya)/(zb-za)
             pic(npuntos) = i
             pjc(npuntos) = j-0.5d0
          else if (zbzc.eq.zero) then
             npuntos = npuntos+1
             if (npuntos.gt.size(xc)) then
                return
             end if
             xc(npuntos) = xb
             yc(npuntos) = yb
             pic(npuntos) = i
             pjc(npuntos) = j
          endif
          ! reassign zazc
          ya = yb
          za = zb
          zazc = zbzc
       enddo
    enddo

    ! run over rows
    do j = 1,ny
       xa = x(1)
       ya = y(j)
       za = ff(1,j)
       zazc = za-zc

       do i = 2, nx
          xb = x(i)
          yb = y(j)
          zb = ff(i,j)
          zbzc = zb-zc
          ! sign changed, interpolate and write a point
          if ((zazc*zbzc).lt.zero) then
             npuntos = npuntos+1
             if (npuntos.gt.size(xc)) then
                return
             end if
             xc(npuntos) = xa-zazc*(xb-xa)/(zb-za)
             yc(npuntos) = yb
             pic(npuntos) = i-0.5d0
             pjc(npuntos) = j
          endif
          ! reassign zazc
          xa = xb
          za = zb
          zazc = zbzc
       enddo
    enddo

  end subroutine hallarpuntos

  !> Determines the connectivity of the set of contour points.
  subroutine ordenarpuntos (luw,calpha,ziso)
    use param, only: one, half, zero
    real*8, parameter :: eps = 0.10d0

    integer, intent(in) :: luw
    real*8, intent(in) :: calpha, ziso

    real*8 :: salpha

    logical :: lc(size(xc)), cerrada, primerabusqueda, hallado
    logical :: malla0, malla1, malla2, incompleta
    integer :: punto(-1*size(xc)-1:size(xc)+1), puntoinicial
    integer :: puntofinal, puntoactual, salto, nptoscurva
    integer :: nptosestudiados
    real*8  :: x(nptcorte+1), y(nptcorte+1)
    integer :: k, n1
    real*8  :: pi0, pj0, pi1, pj1, pi2, pj2, si1, sj1

    ! inline functions
    logical :: adyacentes
    adyacentes(pi0,pj0,pi1,pj1,si1,sj1)=(abs(abs(pi0-pi1)-si1) < eps).and.&
       (abs(abs(pj0-pj1)-sj1) < eps)

    ! initialize
    do k = 1, npuntos
       lc(k) = .false.
    enddo
    nptosestudiados = 0

    ! run over all points
    x = 0d0
    y = 0d0
    n1 = 1
    do while (nptosestudiados.lt.npuntos)

       ! search for a non-used point and start a curve
       k = n1
       do while ((lc(k)) .and. (k.le.npuntos))
          k = k+1
       enddo
       if (k.gt.npuntos) then
          return
       end if
       ! the isoline starts at k
       n1 = k

       lc(n1) = .true.
       pi1 = pic(n1)
       pj1 = pjc(n1)

       ! initialize search vars.
       puntoinicial = 0
       puntofinal = 0
       puntoactual = 0
       punto(puntoactual) = n1
       salto = 1
       primerabusqueda = .true.
       incompleta = .true.
       cerrada = .false.

       ! search
       do while (incompleta)
          hallado = .true.
          do while (hallado)
             hallado = .false.

             ! (pi1,pj1) is the last found point. Search for connection
             ! with the rest of the points in the isoline
             malla1 = (dabs(pi1-dint(pi1)).le.eps) .and.              &
                &                (dabs(pj1-dint(pj1)).le.eps)
             k = n1
             do while ((.not.hallado) .and. (k.lt.npuntos))
                k = k+1
                if (.not.lc(k)) then

                   !.search in non-connected points
                   pi2 = pic(k)
                   pj2 = pjc(k)
                   malla2 = (dabs(pi2-dint(pi2)).le.eps) .and.        &
                      &                      (dabs(pj2-dint(pj2)).le.eps)
                   if (malla1 .or. malla2) then

                      ! one of (pi1,pj1) and (pi2,pj2) is in the grid
                      if (adyacentes(pi1,pj1,pi2,pj2,one,half)        &
                         .or. adyacentes(pi1,pj1,pi2,pj2,half,one)  &
                         .or. adyacentes(pi1,pj1,pi2,pj2,one,zero)  &
                         .or. adyacentes(pi1,pj1,pi2,pj2,zero,one)  &
                         .or. adyacentes(pi1,pj1,pi2,pj2,half,zero) &
                         .or. adyacentes(pi1,pj1,pi2,pj2,zero,half) &
                         .or. adyacentes(pi1,pj1,pi2,pj2,one,one)) then
                         hallado = .true.
                         puntoactual = puntoactual+salto
                         punto(puntoactual) = k
                         puntoinicial = min(puntoinicial,puntoactual)
                         puntofinal = max(puntofinal,puntoactual)
                         lc(k) = .true.
                         pi1 = pi2
                         pj1 = pj2
                      endif
                   else

                      ! none of the points is in the grid. points are 
                      si1 = zero
                      sj1 = zero
                      if (dabs(pi1-dint(pi1)).le.eps) si1 = one
                      if (dabs(pj1-dint(pj1)).le.eps) sj1 = one
                      if (adyacentes(pi1,pj1,pi2,pj2,half,half)       &
                         .or. adyacentes(pi1,pj1,pi2,pj2,si1,sj1)) then
                         hallado = .true.
                         puntoactual = puntoactual+salto
                         punto(puntoactual) = k
                         puntoinicial = min(puntoinicial,puntoactual)
                         puntofinal = max(puntofinal,puntoactual)
                         lc(k) = .true.
                         pi1 = pi2
                         pj1 = pj2
                      endif
                   endif
                endif
             enddo
          enddo

          ! no adyacent point found. Probe if it is a closed or open curve
          if ((puntofinal-puntoinicial+1).gt.2) then
             pi0 = pic(punto(puntoinicial))
             pj0 = pjc(punto(puntoinicial))
             malla0 = (dabs(pi0-dint(pi0)).le.eps) .and.              &
                &                (dabs(pj0-dint(pj0)).le.eps)
             pi1 = pic(punto(puntofinal))
             pj1 = pjc(punto(puntofinal))
             malla1 = (dabs(pi1-dint(pi1)).le.eps) .and.              &
                &                (dabs(pj1-dint(pj1)).le.eps)
             if (malla0 .or. malla1) then
                if (adyacentes(pi0,pj0,pi1,pj1,one,half)              &
                   .or. adyacentes(pi0,pj0,pi1,pj1,half,one)           &
                   .or. adyacentes(pi0,pj0,pi1,pj1,one,zero)           &
                   .or. adyacentes(pi0,pj0,pi1,pj1,zero,one)           &
                   .or. adyacentes(pi0,pj0,pi1,pj1,half,zero)          &
                   .or. adyacentes(pi0,pj0,pi1,pj1,zero,half)          &
                   .or. adyacentes(pi0,pj0,pi1,pj1,one,one)) then
                   cerrada = .true.
                endif
             else
                si1 = zero
                sj1 = zero
                if (dabs(pi1-dint(pi1)).le.eps) si1 = one
                if (dabs(pj1-dint(pj1)).le.eps) sj1 = one
                if (adyacentes(pi0,pj0,pi1,pj1,half,half)             &
                   .or. adyacentes(pi0,pj0,pi1,pj1,si1,sj1)) then
                   cerrada = .true.
                endif
             endif
          endif

          ! closed
          if (cerrada) then
             incompleta = .false.
             puntofinal = puntofinal+1
             punto(puntofinal) = punto(puntoinicial)
             ! open -> back to the first point to explore the other branch
          else if (primerabusqueda) then
             primerabusqueda = .false.
             puntoactual = 0
             salto = -1
             pi1 = pic(punto(puntoactual))
             pj1 = pjc(punto(puntoactual))
             ! curve is complete
          else
             incompleta = .false.
          endif
       enddo

       ! write
       nptoscurva = puntofinal-puntoinicial+1
       do k = puntoinicial, puntofinal
          x(k-puntoinicial+1) = xc(punto(k))
          y(k-puntoinicial+1) = yc(punto(k))
       enddo

       ! transform to non-orthogonal coordinates
       salpha = sqrt(1d0-calpha**2)
       x = x + y * calpha
       y = y * salpha

       call linea(x,y,nptoscurva,luw,ziso)

       ! update number of points
       if (cerrada) nptoscurva = nptoscurva-1
       nptosestudiados = nptosestudiados+nptoscurva
    enddo

  end subroutine ordenarpuntos

  !> Write (x(n),y(n)) curve in luw.
  subroutine linea (x,y,n,luw,ziso)
    use tools_io, only: string
    integer, intent(in) :: n
    real*8, dimension(n), intent(in) :: x, y
    integer, intent(in) :: luw
    real*8, intent(in) :: ziso

    integer :: i

    write (luw,*)
    write (luw,'("# z = ",A)') string(ziso,'e',20,14)
    do i = 1, n
       write (luw,20) x(i), y(i)
    enddo
20  format (1p, 2(1x,e15.8))

  end subroutine linea

  !> Plot of gradient paths and contours in the style of aimpac's grdvec.
  subroutine rhoplot_grdvec()
    use fields, only: f, grd
    use varbas, only: ncpcel, cpcel
    use crystalmod, only: cr
    use global, only: fileroot, eval_next, dunit0, iunit, refden, prunedist
    use tools_io, only: uout, uin, ucopy, getline, lgetword, equal,&
       faterr, ferror, string, ioj_right, fopen_write, getword, fclose
    use tools_math, only: rsindex, plane_scale_extend, assign_ziso, &
       niso_manual, niso_atan, niso_lin, niso_log, niso_bader
    use types, only: scalar_value_noalloc, realloc
    character(len=:), allocatable :: line, word, datafile, rootname
    integer :: lpold, lp, udat, ll, idum, i, j
    integer :: updum, dndum, updum1, dndum1
    real*8  :: xp(3), rhopt
    logical :: doagain, ok, autocheck
    real*8  :: r0(3), r1(3), r2(3), xdum
    real*8  :: q0(3), xo0(3), xo1(3), xo2(3)
    integer :: cpid
    integer :: niso_type, nfi, ix, iy
    real*8 :: sx, sy, zx0, zx1, zy0, zy1, rdum
    real*8 :: ehess(3), x0(3), uu(3), vv(3), lin0, lin1
    logical :: docontour, dograds, goodplane
    integer :: n1, n2, niso, nder
    type(scalar_value_noalloc) :: res
    real*8, allocatable :: ff(:,:), ziso(:)

    ! Header
    write (uout,'("* GRDVEC: gradient paths and contours in 2d")')

    ! Initialization
    grpcpeps = 1d-2
    grprad1 = prunedist
    grprad2 = prunedist
    grprad3 = prunedist
    grpendpt = 1.0d-6
    grphcutoff = 1.0d-3
    grpproj = 1
    rootname = trim(fileroot)
    datafile = trim(fileroot) // ".dat" 
    autocheck = .false.
    norig = 0
    newncriticp = 0
    cpup = 0
    cpdn = 0
    scalex = 1d0
    scaley = 1d0
    docontour = .false.
    dograds = .false.
    nfi = 0
    sx = 1d0
    sy = 1d0
    zx0 = 0d0
    zx1 = 0d0
    zy0 = 0d0
    zy1 = 0d0

    !.Read user options:
    ll = len(line)
    doagain = getline(uin,line,ucopy=ucopy)
    goodplane = .false.
    do while (doagain)
       lp=1
       word = lgetword(line,lp)
       ok = (len_trim(word)>0)  .and. lp.le.ll

       if (equal(word,'files').or.equal(word,'root').or.equal(word,'oname')) then
          rootname = line(lp:)
          datafile = trim(rootname) // ".dat" 

       else if (equal(word,'plane')) then
          ok = eval_next (r0(1), line, lp)
          ok = ok .and. eval_next (r0(2), line, lp)
          ok = ok .and. eval_next (r0(3), line, lp)
          ok = ok .and. eval_next (r1(1), line, lp)
          ok = ok .and. eval_next (r1(2), line, lp)
          ok = ok .and. eval_next (r1(3), line, lp)
          ok = ok .and. eval_next (r2(1), line, lp)
          ok = ok .and. eval_next (r2(2), line, lp)
          ok = ok .and. eval_next (r2(3), line, lp)
          if (.not. ok) then
             call ferror ('grdvec','Bad limits for crystal',faterr,line,syntax=.true.)
             return
          end if
          if (cr%ismolecule) then
             r0 = cr%c2x(r0 / dunit0(iunit) - cr%molx0)
             r1 = cr%c2x(r1 / dunit0(iunit) - cr%molx0)
             r2 = cr%c2x(r2 / dunit0(iunit) - cr%molx0)
          endif
          goodplane = .true.

       elseif (equal(word,'scale')) then
          ok = eval_next(sx,line,lp)
          ok = ok .and. eval_next(sy,line,lp)
          if (.not. ok) then
             call ferror('grdvec','wrong SCALE keyword in PLANE',faterr,line,syntax=.true.)
             return
          end if
       elseif (equal(word,'extendx')) then
          ok = eval_next(zx0,line,lp)
          ok = ok .and. eval_next(zx1,line,lp)
          if (.not. ok) then
             call ferror('grdvec','wrong EXTENDX keyword in PLANE',faterr,line,syntax=.true.)
             return
          end if
          zx0 = zx0 / dunit0(iunit)
          zx1 = zx1 / dunit0(iunit)
       elseif (equal(word,'extendy')) then
          ok = eval_next(zy0,line,lp)
          ok = ok .and. eval_next(zy1,line,lp)
          if (.not. ok) then
             call ferror('grdvec','wrong EXTENDY keyword in PLANE',faterr,line,syntax=.true.)
             return
          end if
          zy0 = zy0 / dunit0(iunit)
          zy1 = zy1 / dunit0(iunit)
       else if (equal(word,'outcp')) then
          ok = eval_next (scalex, line, lp)
          ok = ok .and. eval_next (scaley, line, lp)
          if (.not. ok) then
             call ferror ('grdvec','Bad outcp options',faterr,line,syntax=.true.)
             return
          end if
          ok = check_no_extra_word()
          if (.not.ok) return

       else if (equal(word,'hmax')) then
          ok = eval_next (xdum, line, lp)
          if (ok) RHOP_Hmax = xdum / dunit0(iunit)
          if (.not. ok) then
             call ferror ('grdvec','Wrong hmax line',faterr,line,syntax=.true.)
             return
          end if
          ok = check_no_extra_word()
          if (.not.ok) return
          
       else if (equal(word,'cp')) then
          newncriticp = newncriticp + 1
          if (newncriticp .gt. mncritp) then
             call ferror ('grdvec','too many points in a check order. Increase MNCRITP',faterr,syntax=.true.)
             return
          end if
          ok = eval_next (cpid, line, lp)
          ok = ok .and. eval_next (cpup(newncriticp), line, lp)
          ok = ok .and. eval_next (cpdn(newncriticp), line, lp)
          if (.not. ok) then
             call ferror ('grdvec','bad cp option',faterr,line,syntax=.true.)
             return
          end if
          if (cpid <= 0 .or. cpid > ncpcel) then
             call ferror ('grdvec','cp not recognized',faterr,line,syntax=.true.)
             return
          end if
          newcriticp(:,newncriticp) = cpcel(cpid)%x
          newtypcrit(newncriticp) = cpcel(cpid)%typ
          dograds = .true.
          autocheck = .true.
          ok = check_no_extra_word()
          if (.not.ok) return

       else if (equal(word,'cpall')) then
          ! copy cps
          do i = 1, ncpcel
             newncriticp = newncriticp + 1
             newcriticp(:,newncriticp) = cpcel(i)%x
             newtypcrit(newncriticp) = cpcel(i)%typ
          end do
          dograds = .true.
          autocheck = .true.
          ok = check_no_extra_word()
          if (.not.ok) return

       else if (equal(word,'bcpall')) then
          ok = eval_next (updum, line, lp)
          if (.not.ok) updum = 2
          ok = eval_next (dndum, line, lp)
          if (.not.ok) dndum = 0

          ! copy bcps
          do i = 1, ncpcel
             if (cpcel(i)%typ == -1) then
                newncriticp = newncriticp + 1
                newcriticp(:,newncriticp) = cpcel(i)%x
                newtypcrit(newncriticp) = cpcel(i)%typ
                cpup(newncriticp) = updum
                cpdn(newncriticp) = dndum
             end if
          end do
          dograds = .true.
          autocheck = .true.
          ok = check_no_extra_word()
          if (.not.ok) return
          
       else if (equal(word,'rbcpall')) then
          ok = eval_next (updum, line, lp)
          if (.not.ok) updum = 2
          ok = eval_next (dndum, line, lp)
          if (.not.ok) dndum = 0
          ok = eval_next (updum1, line, lp)
          if (.not.ok) updum1 = 0
          ok = eval_next (dndum1, line, lp)
          if (.not.ok) dndum1 = 2

          ! copy rcps and bcps
          do i = 1, ncpcel
             if (cpcel(i)%typ == -1) then
                newncriticp = newncriticp + 1
                newcriticp(:,newncriticp) = cpcel(i)%x
                newtypcrit(newncriticp) = cpcel(i)%typ
                cpup(newncriticp) = updum
                cpdn(newncriticp) = dndum
             else if (cpcel(i)%typ == 1) then
                newncriticp = newncriticp + 1
                newcriticp(:,newncriticp) = cpcel(i)%x
                newtypcrit(newncriticp) = cpcel(i)%typ
                cpup(newncriticp) = updum1
                cpdn(newncriticp) = dndum1
             end if
          end do
          dograds = .true.
          autocheck = .true.
          ok = check_no_extra_word()
          if (.not.ok) return

       else if (equal(word,'orig')) then
          dograds = .true.
          norig = norig + 1
          if (norig .gt. MORIG) then
             call ferror ('grdvec','Too many ORIGIN points. Increase MORIG',faterr,syntax=.true.)
             return
          end if
          ok = eval_next (grpx(1,norig), line, lp)
          ok = ok .and. eval_next (grpx(2,norig), line, lp)
          ok = ok .and. eval_next (grpx(3,norig), line, lp)
          ok = ok .and. eval_next (grpatr(norig), line, lp)
          ok = ok .and. eval_next (grpup(norig), line, lp)
          ok = ok .and. eval_next (grpdwn(norig), line, lp)
          if (.not. ok) then
             call ferror ('grdvec','Bad limits for 3Dc plot',faterr,line,syntax=.true.)
             return
          end if
          grpx(:,norig) = cr%c2x(grpx(:,norig) / dunit0(iunit) - cr%molx0)
          ok = check_no_extra_word()
          if (.not.ok) return

       elseif (equal (word,'check')) then
          ok = check_no_extra_word()
          if (.not.ok) return
          ! read the user-entered points:
          ok = getline(uin,line,.true.,ucopy)
          lp = 1
          word = lgetword (line,lp)
          do while (ok.and..not.equal(word, 'endcheck').and..not.equal(word, 'end'))
             newncriticp = newncriticp + 1
             if (newncriticp .gt. mncritp) then
                call ferror ('grdvec','too many points in a check order. Increase MNCRITP',faterr,syntax=.true.)
                return
             end if
             lp = 1
             ok = eval_next (newcriticp(1,newncriticp), line, lp)
             ok = ok .and. eval_next (newcriticp(2,newncriticp), line, lp)
             ok = ok .and. eval_next (newcriticp(3,newncriticp), line, lp)
             q0 = cr%x2c(newcriticp(:,newncriticp))
             call grd(f(refden),q0,2,.not.cr%ismolecule,res0_noalloc=res)
             call rsindex(res%hf,ehess,idum,newtypcrit(newncriticp),0d0)
             q0 = cr%c2x(q0)

             ok = ok .and. getline(uin,line,.true.,ucopy)
             lp = 1
             word = lgetword(line,lp)
          enddo
          dograds = .true.
          autocheck = .true.
          ok = check_no_extra_word()
          if (.not.ok) return

       elseif (equal(word,'contour')) then
          
          ! pass contours to the gnu file
          docontour = .true.

          ! read the field
          word = lgetword(line,lp)
          if (equal(word,'f') .or. equal(word,'rho')) then
             nfi = 0
          else if (equal(word,'gx')) then
             nfi = 1
          else if (equal(word,'gy')) then
             nfi = 2
          else if (equal(word,'gz')) then
             nfi = 3
          else if (equal(word,'gmod')) then
             nfi = 4
          else if (equal(word,'hxx')) then
             nfi = 5
          else if (equal(word,'hxy') .or. equal(word,'hyx')) then
             nfi = 6
          else if (equal(word,'hxz') .or. equal(word,'hzx')) then
             nfi = 7
          else if (equal(word,'hyy')) then
             nfi = 8
          else if (equal(word,'hyz') .or. equal(word,'hzy')) then
             nfi = 9
          else if (equal(word,'hzz')) then
             nfi = 10
          else if (equal(word,'lap')) then
             nfi = 11
          else
             call ferror('rhoplot_grdvec','contour field keyword needed',faterr,line,syntax=.true.)
             return
          end if

          ! read the number of points
          ok = eval_next (n1, line, lp)
          ok = ok .and. eval_next (n2, line, lp)
          if (.not.ok) then
             call ferror('rhoplot_grdvec','contour number of points needed',faterr,line,syntax=.true.)
             return
          end if
          n1 = max(n1,2)
          n2 = max(n2,2)

          ok = .true.
          lin0 = 0d0
          lin1 = 1d0
          lpold = lp
          word = lgetword(line,lp)
          if (equal(word,'atan')) then
             niso_type = niso_atan
             ok = eval_next (niso, line, lp)
          else if (equal(word,'log')) then
             niso_type = niso_log
             ok = eval_next (niso, line, lp)
          else if (equal(word,'bader')) then
             niso_type = niso_bader
          else if (equal(word,'lin')) then
             niso_type = niso_lin
             ok = eval_next(niso, line, lp)
             ok = ok .and. eval_next(lin0, line, lp)
             ok = ok .and. eval_next(lin1, line, lp)
          else
             lp = lpold
             niso_type = niso_manual
             if (allocated(ziso)) deallocate(ziso)
             allocate(ziso(1))
             niso = 0
             do while (.true.)
                ok = eval_next(rdum,line,lp)
                if (.not.ok) exit
                niso = niso + 1
                if (niso > size(ziso,1)) call realloc(ziso,2*niso)
                ziso(niso) = rdum
             end do
             if (niso == 0) then
                call ferror("rhoplot_plane","wrong contour values",faterr,line,syntax=.true.)
                return
             end if
             call realloc(ziso,niso)
             ok = .true.
          end if

          if (.not.ok) then
             call ferror ('grdvec','wrong contour values',faterr,line,syntax=.true.)
             return
          end if
          ok = check_no_extra_word()
          if (.not.ok) return

       else if (equal(word,'endgrdvec').or.equal(word,'end')) then
          ok = check_no_extra_word()
          if (.not.ok) return
          goto 999
       else
          call ferror ('grdvec','Unkown keyword in GRDVEC',faterr,line,syntax=.true.)
          return
       endif
       doagain = getline(uin,line,ucopy=ucopy)
    enddo
    call ferror('grdvec','Unexpected end of input',faterr,line,syntax=.true.)
    return
999 continue
    if (.not.goodplane) then
       call ferror ('grdvec','No PLANE given in GRDVEC',faterr,syntax=.true.)
       return
    end if
    
    ! extend and scale
    r0 = cr%x2c(r0)
    r1 = cr%x2c(r1)
    r2 = cr%x2c(r2)
    call plane_scale_extend(r0,r1,r2,sx,sy,zx0,zx1,zy0,zy1)
    r0 = cr%c2x(r0)
    r1 = cr%c2x(r1)
    r2 = cr%c2x(r2)

    ! output the plane
    indmax = nint(max(maxval(abs(r0)),maxval(abs(r1)),maxval(abs(r2))))
    write (uout,'("* Name of the output data file: ",a)') string(datafile)
    if (.not.cr%ismolecule) then
       xo0 = r0
       xo1 = r1
       xo2 = r2
    else
       xo0 = (cr%x2c(r0) + cr%molx0) * dunit0(iunit)
       xo1 = (cr%x2c(r1) + cr%molx0) * dunit0(iunit)
       xo2 = (cr%x2c(r2) + cr%molx0) * dunit0(iunit)
    end if
    write (uout,'("  Plane origin: ",3(A,X))') (string(xo0(j),'f',12,6,ioj_right),j=1,3)
    write (uout,'("  Plane x-end:  ",3(A,X))') (string(xo1(j),'f',12,6,ioj_right),j=1,3)
    write (uout,'("  Plane y-end:  ",3(A,X))') (string(xo2(j),'f',12,6,ioj_right),j=1,3)

    ! calculate the contour plot
    if (docontour) then
       allocate(ff(n1,n2))
       x0 = cr%x2c(r0)
       uu = cr%x2c((r1-r0) / real(n1-1,8))
       vv = cr%x2c((r2-r0) / real(n2-1,8))
       if (nfi == 0) then
          nder = 0
       else if (nfi >= 1 .and. nfi <= 4) then
          nder = 1
       else
          nder = 2
       end if
       !$omp parallel do private (xp,res,rhopt) schedule(dynamic)
       do ix = 1, n1
          do iy = 1, n2
             xp = x0 + real(ix-1,8) * uu + real(iy-1,8) * vv
             call grd(f(refden),xp,nder,.not.cr%ismolecule,res0_noalloc=res)
             select case(nfi)
             case (0)
                rhopt = res%f
             case (1)
                rhopt = res%gf(1)
             case (2)
                rhopt = res%gf(2)
             case (3)
                rhopt = res%gf(3)
             case (4)
                rhopt = res%gfmod
             case (5)
                rhopt = res%hf(1,1)
             case (6)
                rhopt = res%hf(1,2)
             case (7)
                rhopt = res%hf(1,3)
             case (8)
                rhopt = res%hf(2,2)
             case (9)
                rhopt = res%hf(2,3)
             case (10)
                rhopt = res%hf(3,3)
             case (11)
                rhopt = res%del2f
             end select
             !$omp critical (write)
             ff(ix,iy) = rhopt
             !$omp end critical (write)
          end do
       end do
       !$omp end parallel do
       call assign_ziso(niso_type,niso,ziso,lin0,lin1,maxval(ff),minval(ff))
       call contour(ff,r0,r1,r2,n1,n2,niso,ziso,rootname,.false.,.false.)
       if (allocated(ziso)) deallocate(ziso)
       deallocate(ff)
    end if
       
    udat = fopen_write(datafile)
    call plotvec (r0, r1, r2, autocheck, udat)
    call fclose(udat)

    ! print labels (plane info is common)
    call write_fichlabel(rootname)
    
    ! print gnuplot (plane info is common)
    call write_fichgnu(rootname,.true.,docontour,dograds)
    write (uout,*)

  contains

    function check_no_extra_word()
      character(len=:), allocatable :: aux2
      logical :: check_no_extra_word
      aux2 = getword(line,lp)
      check_no_extra_word = .true.
      if (len_trim(aux2) > 0) then
         call ferror('rhoplot_grdvec','Unknown extra keyword',faterr,line,syntax=.true.)
         check_no_extra_word = .false.
      end if
    end function check_no_extra_word

  end subroutine rhoplot_grdvec

  !> Plot of the gradient vector field in the plane defined
  !> by the vectors (r1-r0) & (r2-r0).
  subroutine plotvec (r0, r1, r2, autocheck, udat)
    use navigation, only: gradient
    use fields, only: f, grd
    use global, only: dunit0, iunit, refden
    use crystalmod, only: cr
    use tools_math, only: cross, matinv, rsindex
    use tools_io, only: uout, string, ioj_right, ioj_left
    use param, only: pi
    use types, only: scalar_value
    integer, intent(in) :: udat
    logical, intent(in) :: autocheck
    real*8, dimension(3), intent(in) :: r0, r1, r2

    integer :: nptf, i, j, iorig, up1d, up2d, ntotpts
    real*8  :: xflux(3,RHOP_Mstep), xstart(3), phii, u1, v1, u, v
    real*8  :: r012, v1d(3), v2da(3), v2db(3), xo0(3), xo1(3), xo2(3)
    real*8  :: xtemp(3), c1coef, c2coef, ehess(3)
    integer :: ier, nindex, ntype
    type(scalar_value) :: res

    ! plane metrics
    rp0 = cr%x2c(r0)
    rp1 = cr%x2c(r1)
    rp2 = cr%x2c(r2)
    r01 = 0d0
    r02 = 0d0
    r012 = 0d0
    do i = 1, 3
       rp01(i) = rp1(i) - rp0(i)
       rp02(i) = rp2(i) - rp0(i)
       r01 = r01 + rp01(i) * rp01(i)
       r02 = r02 + rp02(i) * rp02(i)
       r012 = r012 + rp01(i) * rp02(i)
    enddo
    r01 = sqrt(r01)
    r02 = sqrt(r02)
    cosalfa = r012 / (r01*r02)
    a012 = acos(cosalfa)
    sinalfa = sin(a012)
    cotgalfa = cosalfa / sinalfa

    ! normal vector
    rpn(1:3) = cross(rp01,rp02)
    rpn(4) = -dot_product(rpn(1:3),rp0)
    rpn = rpn / (r01*r02)

    ! plane to cartesian
    amat(:,1) = rp01
    amat(:,2) = rp02
    amat(:,3) = rpn(1:3)

    ! cartesian to plane
    bmat = matinv(amat)

    write (uout,'("* Plot of the gradient vector field in the plane:")')
    write (uout,'("    r = r0 + u * (r1 - r0) + v * (r2 - r0)")')
    write (uout,'("  where the parametric coordinates u and v go from 0 to 1.")')
    if (.not.cr%ismolecule) then
       write (uout,'("+ Crystal coordinates of r0: ",3(A,2X))') (string(r0(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Crystal coordinates of r1: ",3(A,2X))') (string(r1(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Crystal coordinates of r2: ",3(A,2X))') (string(r2(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Cartesian coordinates of r0: ",3(A,X))') (string(rp0(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Cartesian coordinates of r1: ",3(A,X))') (string(rp1(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Cartesian coordinates of r2: ",3(A,X))') (string(rp2(j),'f',12,6,ioj_right),j=1,3)
    else
       xo0 = (cr%x2c(r0) + cr%molx0) * dunit0(iunit)
       xo1 = (cr%x2c(r1) + cr%molx0) * dunit0(iunit)
       xo2 = (cr%x2c(r2) + cr%molx0) * dunit0(iunit)
       write (uout,'("+ Coordinates of r0: ",3(A,X))') (string(xo0(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Coordinates of r1: ",3(A,X))') (string(xo1(j),'f',12,6,ioj_right),j=1,3)
       write (uout,'("+ Coordinates of r2: ",3(A,X))') (string(xo2(j),'f',12,6,ioj_right),j=1,3)
    endif
    ! Check the in-plane CPs
    if (autocheck) call autochk(rp0)

    !.Run over the points defined as origins:
    write (uout,'("+ List of critical points that act as in-plane gradient path generators")')
    write (uout,'("# i       xcrys        ycrys        zcrys    iatr   up down     xplane       yplane")')
    do iorig = 1, norig
       ! calculate in-plane coordinates
       xtemp = cr%x2c(grpx(:,iorig))
       xtemp = xtemp - rp0
       xtemp = matmul(bmat,xtemp)
       u = xtemp(1)*r01 + xtemp(2)*r02*cosalfa
       v = xtemp(2)*r02*sinalfa

       xtemp = grpx(:,iorig)
       if (cr%ismolecule) &
          xtemp = (cr%x2c(xtemp) + cr%molx0) * dunit0(iunit)
       write (uout,'(99(A,2X))') string(iorig,length=5,justify=ioj_left), &
          (string(xtemp(j),'f',decimal=6,length=11,justify=4),j=1,3),&
          string(grpatr(iorig),length=3,justify=ioj_right), &
          string(grpup(iorig),length=3,justify=ioj_right), &
          string(grpdwn(iorig),length=3,justify=ioj_right), &
          string(u,'f',decimal=6,length=11,justify=4), string(v,'f',decimal=6,length=11,justify=4)
    enddo
    write (uout,*)
    
    write (uout,'("+ List of gradient paths traced")')
    write (uout,'("# i       xcrys        ycrys        zcrys        type    up down    pts")')
    do iorig = 1, norig
       ntotpts = 0
       grpx(:,iorig) = cr%x2c(grpx(:,iorig))

       if (grpatr(iorig) .eq. 1) then
          ! 3D attraction or repulsion critical points:
          do i = 1, grpup(iorig)
             phii = (i-1) * 2d0 * pi / max(grpup(iorig)-1,1)
             u1 = grprad1 * sin(phii)
             v1 = grprad1 * cos(phii)
             u = (u1 - v1 * cotgalfa) / r01
             v = v1 / (r02 * sinalfa)
             xstart = grpx(:,iorig) + u * rp01 + v * rp02
             call gradient(f(refden),xstart,+1,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
             do j = 1, nptf
                xflux(:,j) = cr%x2c(xflux(:,j))
             end do
             call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
             ntotpts = ntotpts + nptf
          enddo
          do i = 1, grpdwn(iorig)
             phii = (i-1) * 2d0 * pi / max(grpdwn(iorig)-1,1)
             u1 = grprad1 * sin(phii)
             v1 = grprad1 * cos(phii)
             u = (u1 - v1 * cotgalfa) / r01
             v = v1 / (r02 * sinalfa)
             xstart = grpx(:,iorig) + u * rp01 + v * rp02
             call gradient(f(refden),xstart,-1,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
             do j = 1, nptf
                xflux(:,j) = cr%x2c(xflux(:,j))
             end do
             call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
             ntotpts = ntotpts + nptf
          enddo
          nindex = 3
          if (grpup(iorig) > 0) then
             ntype = 3
          else
             ntype = -3
          end if

          xtemp = (grpx(:,iorig) + cr%molx0) * dunit0(iunit)
          
          write (uout,'(4(A,2X),"(",A,","A,") ",3(A,2X))') &
             string(iorig,length=5,justify=ioj_left), &
             (string(xtemp(j),'f',decimal=6,length=11,justify=4),j=1,3),&
             string(nindex,length=3,justify=ioj_right),&
             string(ntype,length=3,justify=ioj_right),&
             string(grpup(iorig),length=3,justify=ioj_right),&
             string(grpdwn(iorig),length=3,justify=ioj_right),&
             string(ntotpts,length=5,justify=ioj_right)
       else
          ! A (3,-1) or (3,+3) critical point:
          xstart = grpx(:,iorig)
          call grd(f(refden),xstart,2,.not.cr%ismolecule,res0=res)
          call rsindex(res%hf,ehess,nindex,ntype,0d0)
          if (nindex .eq. 3) then
             if (ntype .eq. -1) then
                up1d = +1
                up2d = -1
                if (grpup(iorig)  .eq. 0) up1d = 0
                if (grpdwn(iorig) .eq. 0) up2d = 0
                v2da(1) = res%hf(1,1)
                v2da(2) = res%hf(2,1)
                v2da(3) = res%hf(3,1)
                v2db(1) = res%hf(1,2)
                v2db(2) = res%hf(2,2)
                v2db(3) = res%hf(3,2)
                v1d(1)  = res%hf(1,3)
                v1d(2)  = res%hf(2,3)
                v1d(3)  = res%hf(3,3)
             else if (ntype .eq. +1) then
                up1d = -1
                up2d = +1
                if (grpup(iorig)  .eq. 0) up2d = 0
                if (grpdwn(iorig) .eq. 0) up1d = 0
                v1d(1)  = res%hf(1,1)
                v1d(2)  = res%hf(2,1)
                v1d(3)  = res%hf(3,1)
                v2da(1) = res%hf(1,2)
                v2da(2) = res%hf(2,2)
                v2da(3) = res%hf(3,2)
                v2db(1) = res%hf(1,3)
                v2db(2) = res%hf(2,3)
                v2db(3) = res%hf(3,3)
             else
                up1d = 0
                up2d = 0
             endif
             if (up2d .ne. 0) then
                !.2D walk:
                c1coef = dot_product(v2db,rpn(1:3))
                c2coef = -dot_product(v2da,rpn(1:3))

                if (abs(c1coef) < 1d-10 .and. abs(c2coef) < 1d-10) then
                   ! the plot plane is coincident with the ias tangent plane
                   ! use v2da.
                   xstart = grpx(:,iorig) + grprad2 * v2da
                   call gradient(f(refden),xstart,-1,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
                   do j = 1, nptf
                      xflux(:,j) = cr%x2c(xflux(:,j))
                   end do
                   call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
                   ntotpts = ntotpts + nptf
                   xstart = grpx(:,iorig) - grprad2 * v2da
                   call gradient(f(refden),xstart,up2d,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
                   do j = 1, nptf
                      xflux(:,j) = cr%x2c(xflux(:,j))
                   end do
                   call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
                   ntotpts = ntotpts + nptf
                else
                   xtemp = c1coef * v2da + c2coef * v2db
                   xstart = grpx(:,iorig) + grprad2 * xtemp
                   call gradient(f(refden),xstart,up2d,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
                   do j = 1, nptf
                      xflux(:,j) = cr%x2c(xflux(:,j))
                   end do
                   call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
                   ntotpts = ntotpts + nptf
                   xstart = grpx(:,iorig) - grprad2 * xtemp
                   call gradient(f(refden),xstart,up2d,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
                   do j = 1, nptf
                      xflux(:,j) = cr%x2c(xflux(:,j))
                   end do
                   call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
                   ntotpts = ntotpts + nptf
                end if

             endif
             if (up1d .ne. 0) then
                !
                !.................1D walk:
                !
                xstart = grpx(:,iorig) + grprad3 * v1d
                call gradient(f(refden),xstart,up1d,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
                do j = 1, nptf
                   xflux(:,j) = cr%x2c(xflux(:,j))
                end do
                call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
                xstart = grpx(:,iorig) - grprad3 * v1d
                call gradient(f(refden),xstart,up1d,nptf,RHOP_Mstep,ier,1,xflux,up2beta=.false.)
                do j = 1, nptf
                   xflux(:,j) = cr%x2c(xflux(:,j))
                end do
                call wrtpath (xflux,nptf,RHOP_Mstep,udat,rp0,r01,r02,cosalfa,sinalfa)
                ntotpts = ntotpts + nptf
             endif
          endif

          xtemp = (grpx(:,iorig) + cr%molx0) * dunit0(iunit)

          write (uout,'(4(A,2X),"(",A,","A,") ",3(A,2X))') &
             string(iorig,length=5,justify=ioj_left), &
             (string(xtemp(j),'f',decimal=6,length=11,justify=4),j=1,3),&
             string(nindex,length=3,justify=ioj_right),&
             string(ntype,length=3,justify=ioj_right),&
             string(grpup(iorig),length=3,justify=ioj_right),&
             string(grpdwn(iorig),length=3,justify=ioj_right),&
             string(ntotpts,length=5,justify=ioj_right)
       endif
    enddo
    write (uout,*)

  end subroutine plotvec

  !> Write the gradient path to the udat logical unit.
  subroutine wrtpath (xflux, nptf, mptf, udat, rp0, r01, r02, cosalfa, sinalfa)
    use crystalmod, only: cr
    use global, only: prunedist
    use param, only: jmlcol
    integer, intent(in) :: mptf
    real*8, dimension(3,mptf), intent(in) :: xflux
    integer, intent(in) :: nptf
    integer, intent(in) :: udat
    real*8, intent(in) :: rp0(3), r01, r02, cosalfa, sinalfa

    integer :: i, j, nid1, nid2, lvec(3), iz, rgb(3)
    real*8 :: xxx, yyy, zzz, u, v, h, uort, vort, x0(3)
    real*8 :: dist1, dist2
    logical :: wasblank

    ! identify the endpoints
    x0 = cr%c2x(xflux(:,1))
    nid1 = 0
    call cr%nearest_atom(x0,nid1,dist1,lvec)
    x0 = cr%c2x(xflux(:,nptf))
    nid2 = 0
    call cr%nearest_atom(x0,nid2,dist2,lvec)
    rgb = (/0,0,0/)
    if (dist1 < dist2 .and. dist1 < 1.1d0*prunedist) then
       iz = cr%at(cr%atcel(nid1)%idx)%z
       if (iz /= 1) rgb = jmlcol(:,iz)
    elseif (dist2 < dist1 .and. dist2 < 1.1d0*prunedist) then
       iz = cr%at(cr%atcel(nid2)%idx)%z
       if (iz /= 1) rgb = jmlcol(:,iz)
    endif

    write (udat,*)
    write (udat,*)
    wasblank = .true.
    do i = 1, nptf
       !.transform the point to the plotting plane coordinates:
       xxx = xflux(1,i) - rp0(1)
       yyy = xflux(2,i) - rp0(2)
       zzz = xflux(3,i) - rp0(3)
       u = bmat(1,1)*xxx + bmat(1,2)*yyy + bmat(1,3)*zzz
       v = bmat(2,1)*xxx + bmat(2,2)*yyy + bmat(2,3)*zzz
       h = bmat(3,1)*xxx + bmat(3,2)*yyy + bmat(3,3)*zzz

       !.clip the line if it is out of the plotting area:
       if (u < 0d0 .or. u > 1d0 .or. v < 0d0 .or. v > 1d0) then
          ! print the last point so that gnuplot interpolates to the edge
          if (i-1 >= 1) then
             uort = u*r01 + v*r02*cosalfa
             vort = v*r02*sinalfa
             if (abs(h) < grphcutoff .or. grpproj > 0) then
                write (udat,200) uort, vort, (xflux(j,i), j = 1, 3), (rgb(1) * 256 + rgb(2)) * 256 + rgb(3)
             end if
          end if
          if (.not.wasblank) write (udat,*)
          wasblank = .true.
       else
          wasblank = .false.
          uort = u*r01 + v*r02*cosalfa
          vort = v*r02*sinalfa
          if (abs(h) < grphcutoff .or. grpproj > 0) then
             write (udat,200) uort, vort, (xflux(j,i), j = 1, 3), (rgb(1) * 256 + rgb(2)) * 256 + rgb(3)
          end if
       endif
    enddo

200 format (2f15.9, 1p, 3e15.6, I10)

  end subroutine wrtpath

  !> Check a user-entered collection of points to see if they
  !> are critical points, remove repeated points, and check which
  !> equivalents (within the main cell) lie on the plotting plane.
  subroutine autochk(rp0)
    use fields, only: f, grd
    use crystalmod, only: cr
    use global, only: refden, cp_hdegen
    use tools_io, only: uout, string, ioj_left, ioj_right, faterr, ferror
    use tools_math, only: rsindex
    use param, only: one
    use types, only: scalar_value
    integer :: i, j, k, l, ncopies
    integer :: iorde(2*indmax+1), indcell(3,(2*indmax+1)**3), iii, inum
    real*8  :: xp(3)
    real*8  :: x0(3), x1(3), uu, vv, hh, hmin
    integer :: nindex
    type(scalar_value) :: res
    real*8 :: rp0(3), ehess(3)

    ! 
    write (uout,'("+ List of candidate in-plane CPs")') 
    write (uout,'("# cp       x           y           z")')
    do i = 1, newncriticp
       newcriticp(:,i) = newcriticp(:,i) - floor(newcriticp(:,i))
       write (uout,'(2X,4(A,2X))') string(i,length=3,justify=ioj_left), &
          (string(newcriticp(j,i),'f',10,6,ioj_right),j=1,3)
    enddo
    write (uout,*)

    inum = 2*indmax+1
    do i=1,inum
       iorde(i) = i-1-indmax
    end do

    iii = 0
    do i = 1, inum
       do j = 1, inum
          do k = 1, inum
             iii = iii + 1
             indcell(1,iii) = iorde(i)
             indcell(2,iii) = iorde(j)
             indcell(3,iii) = iorde(k)
          enddo
       enddo
    enddo

    write (uout,'("+ Pruning actions on the in-plane CP list")') 
    do i = 1, newncriticp
       xp = newcriticp(:,i)

       !.discard repeated points
       do j = i+1, newncriticp
          if (cr%are_close(newcriticp(:,j),xp,epsf)) then
             write (uout,'(2X,"CP ",A," is equivalent to ",A," -> Rejected!")') string(j), string(i)
             cycle
          endif
       enddo

       !.Get the properties
       xp = cr%x2c(newcriticp(:,i))
       call grd(f(refden),xp,2,.not.cr%ismolecule,res0=res)
       if (res%gfmod > grpcpeps) then
          write (uout,'(2X,"CP ",A," has a large gradient: ",A," -> Rejected!")') &
             string(i), string(res%gfmod,'e',decimal=6)
          cycle
       else
          if (newtypcrit(i) == 0) then
             call rsindex(res%hf,ehess,nindex,newtypcrit(i),CP_hdegen)
          end if
       endif

       !.Determine the points to be added as gradient path origins:
       ncopies = 0
       hmin = 1d30
       do l = 1, (inum)**3
          xp = cr%x2c(newcriticp(:,i) + indcell(:,l))

          !.transform the point to the plotting plane coordinates:
          x0 = xp - rp0
          x1 = matmul(bmat,x0)
          uu = x1(1)
          vv = x1(2)
          hh = x1(3)

          !.clip if out of the plotting area
          hmin = min(hmin,abs(hh))
          if (uu >= -epsdis+(one-scalex) .and. uu <= scalex+epsdis .and.&
              vv >= -epsdis+(one-scaley) .and. vv <= scaley+epsdis .and.&
              abs(hh) <= RHOP_Hmax) then
             ncopies = ncopies + 1
             if (norig .ge. MORIG) then
                call ferror('autochk', 'Too many origins. Increase MORIG',faterr,syntax=.true.)
                return
             endif
             norig = norig + 1
             grpx(:,norig) = newcriticp(:,i) + indcell(:,l)
             if (cpup(i) > 0 .or. cpdn(i) > 0) then
                if (newtypcrit(i) == -3 .or. newtypcrit(i) == +3) then
                   grpatr(norig) = 1
                else
                   grpatr(norig) = 0
                endif
                grpup(norig) = cpup(i)
                grpdwn(norig) = cpdn(i)
             else
                if (newtypcrit(i) == -3) then
                   grpatr(norig) = 1
                   grpup(norig)  = 0
                   grpdwn(norig) = 36
                else if (newtypcrit(i) == +3) then
                   grpatr(norig) = 1
                   grpup(norig)  = 36
                   grpdwn(norig) = 0
                else
                   grpatr(norig) = 0
                   grpup(norig)  = 2
                   grpdwn(norig) = 2
                endif
             end if
          endif
       enddo
       write (uout,'(2X,"CP ",A," created ",A," copies in plane (hmin = ",A,")")') &
          string(i), string(ncopies), string(hmin,'f',decimal=6)
    end do
    write (uout,*)

  end subroutine autochk

  !> Writes the "label" file to rootname-label.gnu. The labels file
  !> contains the list of critical points contained in the plot
  !> plane, ready to be read in gnuplot.
  subroutine write_fichlabel(rootname)
    use varbas, only: ncpcel, cpcel
    use crystalmod, only: cr
    use tools_io, only: uout, string, fopen_write, fclose, nameguess
    use param, only: one
    character*(*), intent(in) :: rootname

    character(len=:), allocatable :: fichlabel
    integer :: i, j, k, iii
    integer :: inum, iorde(2*indmax+1), indcell(3,(2*indmax+1)**3)
    integer :: lul
    real*8 :: xp(3), xxx, yyy, zzz, uu, vv, hh, u, v
    character*2 :: cpletter

    fichlabel = trim(rootname) // "-label.gnu" 

    write (uout,'("* Name of the labels file: ",a)') string(fichlabel)
    write (uout,*)

    ! Create labels file
    lul = fopen_write(fichlabel)
    inum = 2*indmax+1
    do i=1,inum
       iorde(i) = i-1-indmax
    end do
    iii = 0
    do i = 1, inum
       do j = 1, inum
          do k = 1, inum
             iii = iii + 1
             indcell(1,iii) = iorde(i)
             indcell(2,iii) = iorde(j)
             indcell(3,iii) = iorde(k)
          enddo
       enddo
    enddo

    ! write (uout,'("+ CPs accepted/rejected in the plot plane ")')
    ! write (uout,'("A?(cp,lvec)       u               v               h")')
    do i = 1, ncpcel
       do j = 1, (inum)**3
          xp = cr%x2c(cpcel(i)%x + indcell(:,j))
          xxx = xp(1) - rp0(1)
          yyy = xp(2) - rp0(2)
          zzz = xp(3) - rp0(3)
          uu = bmat(1,1)*xxx + bmat(1,2)*yyy + bmat(1,3)*zzz
          vv = bmat(2,1)*xxx + bmat(2,2)*yyy + bmat(2,3)*zzz
          hh = bmat(3,1)*xxx + bmat(3,2)*yyy + bmat(3,3)*zzz
          u = uu*r01+vv*r02*cosalfa
          v = vv*r02*sinalfa

          if (uu.ge.-epsdis .and. uu.le.one+epsdis .and. &
             vv.ge.-epsdis .and. vv.le.one+epsdis .and. &
             abs(hh).le.RHOP_Hmax) then
             ! write (uout,'("A(",A,",",A,")",X,3(A,X))') &
             !    string(i,length=3), string(j,length=3),&
             !    string(u,'e',length=15,decimal=8,justify=4),&
             !    string(v,'e',length=15,decimal=8,justify=4),&
             !    string(hh,'e',length=15,decimal=8,justify=4)

             ! assign cp letter
             ! check if it is a nucleus
             select case (cpcel(i)%typ)
             case (3)
                cpletter = "c"
             case (1)
                cpletter = "r"
             case (-1)
                cpletter = "b"
             case (-3)
                if (cpcel(i)%isnuc) then
                   cpletter = nameguess(cr%at(cpcel(i)%idx)%z,.true.)
                else
                   cpletter = "n"
                endif
             end select
             write (lul,'(3a,f12.6,a,f12.6,a)') 'set label "',trim(cpletter),'" at ',u,',',v,' center front'
          else
             ! write(uout,'("r(",A,",",A,")",X,3(A,X))') &
             !    string(i,length=3), string(j,length=3), string(u,'e',length=15,decimal=8,justify=4),&
             !    string(v,'e',length=15,decimal=8,justify=4),&
             !    string(hh,'e',length=15,decimal=8,justify=4)
          end if
       end do
    end do
    ! write (uout,*)
    call fclose(lul)

  end subroutine write_fichlabel

  !> Writes the gnuplot file rootname.gnu. If dolabels, write the
  !> labels file too. If docontour, write the .iso (postivie iso
  !> -values) and the .neg.iso (negative iso-values). If dograds,
  !> write the file containing the gradient paths.
  subroutine write_fichgnu(rootname,dolabels,docontour,dograds)
    use tools_io, only: uout, string, fopen_write, string, fclose
    character*(*), intent(in) :: rootname
    logical, intent(in) :: dolabels, docontour, dograds
    
    integer :: lun
    character(len=:), allocatable :: fichgnu, fichlabel, fichiso, fichiso1, fichgrd
    character(len=:), allocatable :: swri

    fichgnu = trim(rootname) // '.gnu' 
    fichlabel = trim(rootname) // "-label.gnu" 
    fichiso = trim(rootname) // ".iso" 
    fichiso1 = trim(rootname) // ".neg.iso" 
    fichgrd = trim(rootname) // ".dat" 

    write (uout,'("* Name of the gnuplot script file: ",a/)') string(fichgnu)

    lun=fopen_write(fichgnu)

    write (lun,*) "set terminal postscript eps color enhanced size 10,7 'Helvetica' 40"
    write (lun,*) "set style line 1 lt 1 lc rgbcolor variable lw 4"
    write (lun,*) 'set style line 2 lt 1 lc rgbcolor "#007700"'
    write (lun,*) 'set style line 3 lt 4 lc rgbcolor "#0000ff"'
    write (lun,*) 'set output "' // trim(rootname) // '.eps"'
    write (lun,*) 'set size ratio -1'
    write (lun,*) 'unset key'
    ! title
    write (lun,*) 'set xlabel "x"'
    write (lun,*) 'set ylabel "y"'
    ! ranges
    write (lun,18) min(0d0,r02*cosalfa),&
       max(r01,r01+r02*cosalfa),0d0,r02*sinalfa
    ! labels
    if (dolabels) &
       write (lun,*) 'load "',string(fichlabel),'"'
    ! contours
    swri = ""
    if (docontour) then
       swri = swri // """" // string(fichiso) // """ with lines ls 2"
       if (isneg) &
          swri = swri // ", """ // string(fichiso1) // """ with lines ls 3"
       if (dograds) swri = swri // ", "
    end if
    if (dograds) then
       swri = swri // """" // string(fichgrd) // """ u 1:2:6 with lines ls 1"
    end if

    write (lun,'("plot ",A)') swri
    call fclose(lun)
    
 18   format (1x,'set xrange [',f7.3,':',f7.3,'] '/                     &
     &        1x,'set yrange [',f7.3,':',f7.3,']')

  end subroutine write_fichgnu

end module rhoplot

