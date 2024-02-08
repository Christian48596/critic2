! Copyright (c) 2007-2022 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

! Routines for atomic environments and distance calculations.
submodule (crystalmod) env
  implicit none

contains

  !> Fill the environment variables (nblock, iblock0, blockrmax) as
  !> well as the %inext field in the complete atom list
  !> atoms. Requires the reduced lattice vectors as well as the
  !> complete atom list.
  module subroutine build_env(c)
    use tools_math, only: det3, cross
    use param, only: pi
    class(crystal), intent(inout) :: c

    integer :: i, ix(3)
    real*8 :: xred(3,3), xlen(3), aux, xr(3)

    real*8, parameter :: lenmax = 15d0

    ! calculate the number of cells in each direction and the lattice vectors
    do i = 1, 3
       c%nblock(i) = ceiling(norm2(c%m_xr2c(:,i))/lenmax)
       xred(:,i) = c%m_xr2c(:,i) / c%nblock(i)
    end do

    ! block volume and block radius
    c%blockomega = det3(xred)
    c%blockrmax = 0.5d0 * c%blockomega / max(norm2(cross(xred(:,1),xred(:,2))),&
       norm2(cross(xred(:,1),xred(:,3))),norm2(cross(xred(:,2),xred(:,3))))
    do i = 1, 3
       xlen(i) = norm2(xred(:,i))
    end do
    c%blockcv(1) = norm2(cross(xred(:,2),xred(:,3)))
    c%blockcv(2) = norm2(cross(xred(:,1),xred(:,3)))
    c%blockcv(3) = norm2(cross(xred(:,1),xred(:,2)))

    ! assign atomic indices
    if (allocated(c%iblock0)) deallocate(c%iblock0)
    allocate(c%iblock0(0:c%nblock(1)-1,0:c%nblock(2)-1,0:c%nblock(3)-1))
    c%iblock0 = 0
    c%atcel(:)%inext = 0
    do i = 1, c%ncel
       xr = c%x2xr(c%atcel(i)%x)
       xr = xr - floor(xr)
       ix = min(max(floor(xr * c%nblock),0),c%nblock-1)
       c%atcel(i)%inext = c%iblock0(ix(1),ix(2),ix(3))
       c%iblock0(ix(1),ix(2),ix(3)) = i
    end do

  end subroutine build_env

  !> Given the point xp (in icrd coordinates), calculate the list of
  !> nearest atoms. If sorted is true, the list is sorted by distance
  !> and shell. One (and only one) of these criteria must be given:
  !> - up2d = list up to a distance up2d.
  !> - up2dsp = between a minimum and a maximum species-dependent distance.
  !> - up2dcidx = up to a distance to each atom in the complete list.
  !> - up2sh = up to a number of shells.
  !> - up2n = up to a number of atoms.
  !> The atom list with up2n is sorted by distance on output.
  !>
  !> Optional input:
  !> - nid0 = consider only atoms with index nid0 from the nneq list.
  !> - id0 = consider only atoms with index id0 from the complete list.
  !> - iz0 = consider only atoms with atomic number iz0.
  !> - ispc0 = consider only species with species ID ispc0.
  !> - nozero = disregard zero-distance atoms.
  !>
  !> Output:
  !> - nat = the list contains nat atoms.
  !>
  !> Optional output:
  !> - eid(nid) = atom ID from the complete atom list.
  !> - dist(nid) = distance from xp.
  !> - lvec(3,nid) = lattice vectors for the atoms.
  !> - ishell0(nid) = shell ID.
  !>
  !> This routine is thread-safe.
  module subroutine list_near_atoms(c,xp,icrd,sorted,nat,eid,dist,lvec,ishell0,up2d,&
     up2dsp,up2dcidx,up2sh,up2n,nid0,id0,iz0,ispc0,nozero)
    use hashmod, only: hash
    use tools, only: mergesort
    use tools_io, only: ferror, faterr
    use tools_math, only: cross, det3
    use types, only: realloc
    use param, only: icrd_cart, icrd_crys, icrd_rcrys
    class(crystal), intent(inout) :: c
    real*8, intent(in) :: xp(3)
    integer, intent(in) :: icrd
    logical, intent(in) :: sorted
    integer, intent(out) :: nat
    integer, allocatable, intent(inout), optional :: eid(:)
    real*8, allocatable, intent(inout), optional :: dist(:)
    integer, allocatable, intent(inout), optional :: lvec(:,:)
    integer, allocatable, intent(inout), optional :: ishell0(:)
    real*8, intent(in), optional :: up2d
    real*8, intent(in), optional :: up2dsp(1:c%nspc,2)
    real*8, intent(in), optional :: up2dcidx(1:c%ncel)
    integer, intent(in), optional :: up2sh
    integer, intent(in), optional :: up2n
    integer, intent(in), optional :: nid0
    integer, intent(in), optional :: id0
    integer, intent(in), optional :: iz0
    integer, intent(in), optional :: ispc0
    logical, intent(in), optional :: nozero

    logical :: ok, nozero_, docycle, sorted_
    real*8 :: x(3), xorigc(3), dmax, dd, lvecx(3), xr(3)
    integer :: i, j, k, ix(3), nx(3), i0(3), i1(3), idx, nn
    integer :: ib(3), ithis(3), nsafe, up2n_, nseen
    integer, allocatable :: at_id(:), at_lvec(:,:)
    real*8, allocatable :: at_dist(:), rshel(:)
    integer :: nb, nshellb
    integer, allocatable :: idb(:,:), iaux(:), iord(:)
    integer :: nshel

    real*8, parameter :: eps = 1d-10
    integer, parameter :: ixmol_cut = 10 ! cutoff for switching to no-block molecule dist search
    real*8, parameter :: shell_eps = 1d-5

    ! process input
    nozero_ = .false.
    sorted_ = sorted .or. present(up2n) .or. present(up2sh)
    if (present(nozero)) nozero_ = nozero
    if (present(up2d)) then
       dmax = up2d
    elseif (present(up2dsp)) then
       dmax = maxval(up2dsp)
    elseif (present(up2dcidx)) then
       dmax = maxval(up2dcidx)
    elseif (present(up2n)) then
       !
    elseif (present(up2sh)) then
       !
    else
       call ferror("list_near_atoms","must give one of up2d, up2dsp, up2dcidx, up2sh, or up2n",faterr)
    end if

    ! locate the block containing the point
    if (icrd == icrd_crys) then
       x = c%x2xr(xp)
    elseif (icrd == icrd_cart) then
       x = c%c2xr(xp)
    else
       x = xp
    end if
    xorigc = c%xr2c(x)
    ix = floor(x * c%nblock)

    ! allocate space for atoms
    nat = 0
    nn = 20
    if (present(up2n)) nn = min(up2n,20)
    allocate(at_id(nn),at_dist(nn),at_lvec(3,nn))
    at_id = 0
    at_dist = 0d0
    at_lvec = 0

    ! run the search
    if (present(up2sh).or.present(up2n)) then
       ! cap the number of shells or the number of atoms

       up2n_ = 0
       if (present(up2sh)) then
          ! initialize shell list
          nshel = 0
          allocate(rshel(up2sh))
       else
          up2n_ = up2n
          if (c%ismolecule) up2n_ = min(up2n,c%ncel)
       end if

       if (c%ismolecule .and. maxval(min(abs(ix), abs(ix-c%nblock))) > ixmol_cut) then
          ! this point is too far away from the molecule: calculate
          ! the distance to every atom in the molecule
          nat = c%ncel
          nsafe = nat
          dmax = huge(1d0)
          call realloc(at_id,nat)
          call realloc(at_dist,nat)
          call realloc(at_lvec,3,nat)
          do i = 1, c%ncel
             dd = norm2(c%atcel(i)%r - xorigc)
             at_id(i) = i
             at_dist(i) = dd
             at_lvec(:,i) = 0
             if (present(up2sh)) &
                call add_shell_to_output_list()
          end do
       else
          ! Run over shells of nearby blocks and find atoms until we
          ! have at least the given number of shells
          nseen = 0
          nshellb = 0
          do while(.true.)
             call make_block_shell(nshellb)

             do i = 1, nb
                ithis = idb(:,i) + ix

                if (c%ismolecule) then
                   if (ithis(1) < 0 .or. ithis(1) >= c%nblock(1) .or.&
                      ithis(2) < 0 .or. ithis(2) >= c%nblock(2) .or.&
                      ithis(3) < 0 .or. ithis(3) >= c%nblock(3)) cycle
                   ib = ithis
                   lvecx = 0
                else
                   ib = (/modulo(ithis(1),c%nblock(1)), modulo(ithis(2),c%nblock(2)), modulo(ithis(3),c%nblock(3))/)
                   lvecx = real((ithis - ib) / c%nblock,8)
                end if

                ! run over atoms in this block
                idx = c%iblock0(ib(1),ib(2),ib(3))
                do while (idx /= 0)
                   ! increment the number of "seen" atoms
                   nseen = nseen + 1

                   ! apply filters
                   docycle = .false.
                   if (present(nid0)) &
                      docycle = (c%atcel(idx)%idx /= nid0)
                   if (present(ispc0)) &
                      docycle = (c%atcel(idx)%is /= ispc0)
                   if (present(id0)) &
                      docycle = (idx /= id0)
                   if (present(iz0)) &
                      docycle = (c%spc(c%atcel(idx)%is)%z /= iz0)

                   if (.not.docycle) then
                      ! calculate distance
                      if (c%ismolecule) then
                         x = c%atcel(idx)%r
                      else
                         xr = c%x2xr(c%atcel(idx)%x)
                         xr = xr - floor(xr) + lvecx
                         x = c%xr2c(xr)
                      end if
                      dd = norm2(x - xorigc)

                      ! check if we should add the atom to the list
                      ok = .true.
                      if (nozero_ .and. dd < eps) ok = .false.
                      if (ok) then
                         call add_atom_to_output_list()
                         if (present(up2sh)) &
                            call add_shell_to_output_list()
                      end if
                   end if

                   ! next atom
                   idx = c%atcel(idx)%inext
                end do ! while idx
             end do

             if (present(up2sh)) then
                ! exit if we have enough shells
                nsafe = count(rshel(1:nshel) <= dmax)
                if (nsafe >= up2sh) exit
             else
                ! check if we have enough atoms
                nsafe = count(at_dist(1:nat) <= dmax)
                if (nsafe >= up2n_) exit
             end if

             ! exit if we have examined all atoms in the molecule
             if (c%ismolecule .and. nseen == c%ncel) then
                up2n_ = min(up2n_,nat)
                exit
             end if

             ! next shell
             nshellb = nshellb + 1
          end do ! while loop
       end if

       if (present(up2n) .and. up2n_ == 1) then
          ! bypass for efficiency: handle the case when up2n = 1 (nearest atom)
          idx = minloc(at_dist(1:nat),1)
          nat = 1
          at_dist(1) = at_dist(idx)
          at_id(1) = at_id(idx)
          at_lvec(:,1) = at_lvec(:,idx)
          sorted_ = .false.
       else
          if (present(up2sh)) then
             ! re-calculate the dmax based on the shell radii
             allocate(iord(nshel))
             do i = 1, nshel
                iord(i) = i
             end do
             call mergesort(rshel,iord,1,nshel)
             if (c%ismolecule .and. nshel < up2sh) then
                dmax = rshel(iord(nshel)) + shell_eps
             else
                dmax = rshel(iord(up2sh)) + shell_eps
             end if
             deallocate(rshel,iord)
          end if

          ! filter out the unneeded atoms
          nsafe = count(at_dist(1:nat) <= dmax)
          allocate(iaux(nsafe))
          nsafe = 0
          do i = 1, nat
             if (at_dist(i) <= dmax) then
                nsafe = nsafe + 1
                iaux(nsafe) = i
             end if
          end do
          nat = nsafe
          at_id(1:nsafe) = at_id(iaux)
          at_dist(1:nsafe) = at_dist(iaux)
          at_lvec(:,1:nsafe) = at_lvec(:,iaux)
          call realloc(at_id,nsafe)
          call realloc(at_dist,nsafe)
          call realloc(at_lvec,3,nsafe)
          deallocate(iaux)
       end if
    else
       ! find atoms up to a given distance

       ! calculate the number of blocks in each direction required for satifying
       ! that the largest sphere in the super-block has radius > dmax.
       ! r = Vblock / 2 / max(cv(3)/n3,cv(2)/n2,cv(1)/n1)
       nx = ceiling(c%blockcv / (0.5d0 * c%blockomega / max(dmax,1d-40)))

       ! define the search space
       do i = 1, 3
          if (mod(nx(i),2) == 0) then
             i0(i) = ix(i) - nx(i)/2
             i1(i) = ix(i) + nx(i)/2
          else
             i0(i) = ix(i) - (nx(i)/2+1)
             i1(i) = ix(i) + (nx(i)/2+1)
          end if
       end do

       ! run over the atoms and compile the list
       do i = i0(1), i1(1)
          do j = i0(2), i1(2)
             do k = i0(3), i1(3)
                if (c%ismolecule) then
                   if (i < 0 .or. i >= c%nblock(1) .or. j < 0 .or. j >= c%nblock(2) .or.&
                      k < 0 .or. k >= c%nblock(3)) cycle
                   ib = (/i, j, k/)
                   lvecx = 0
                else
                   ib = (/modulo(i,c%nblock(1)), modulo(j,c%nblock(2)), modulo(k,c%nblock(3))/)
                   lvecx = real(((/i,j,k/) - ib) / c%nblock,8)
                end if

                ! run over atoms in this block
                idx = c%iblock0(ib(1),ib(2),ib(3))
                do while (idx /= 0)
                   ! apply filters
                   docycle = .false.
                   if (present(nid0)) &
                      docycle = (c%atcel(idx)%idx /= nid0)
                   if (present(ispc0)) &
                      docycle = (c%atcel(idx)%is /= ispc0)
                   if (present(id0)) &
                      docycle = (idx /= id0)
                   if (present(iz0)) &
                      docycle = (c%spc(c%atcel(idx)%is)%z /= iz0)

                   if (.not.docycle) then
                      ! calculate distance
                      if (c%ismolecule) then
                         x = c%x2c(c%atcel(idx)%x)
                      else
                         xr = c%x2xr(c%atcel(idx)%x)
                         xr = xr - floor(xr) + lvecx
                         x = c%xr2c(xr)
                      end if
                      dd = norm2(x - xorigc)

                      ! check if we should add the atom to the list
                      ok = .true.
                      if (nozero_ .and. dd < eps) then
                         ok = .false.
                      elseif (present(up2d)) then
                         ok = (dd <= dmax)
                      elseif (present(up2dsp)) then
                         ok = (dd >= up2dsp(c%atcel(idx)%is,1) .and. dd <= up2dsp(c%atcel(idx)%is,2))
                      elseif (present(up2dcidx)) then
                         ok = (dd <= up2dcidx(idx))
                      end if
                      if (ok) call add_atom_to_output_list()
                   end if

                   ! next atom
                   idx = c%atcel(idx)%inext
                end do ! while idx
             end do ! k = i0(3), i1(3)
          end do ! j = i0(2), i1(2)
       end do ! i = i0(1), i1(1)
    end if

    ! sort if necessary
    if (sorted_ .and. nat > 1) then
       ! permutation vector
       allocate(iord(nat))
       do i = 1, nat
          iord(i) = i
       end do

       ! sort by distance
       call mergesort(at_dist,iord,1,nat)

       ! reorder and clean up
       at_id = at_id(iord)
       at_dist = at_dist(iord)
       at_lvec = at_lvec(:,iord)
       deallocate(iord)
    end if

    ! reduce the list if up2n (always sorted)
    if (present(up2n)) nat = up2n_

    ! assign optional outputs
    if (present(eid)) eid = at_id(1:nat)
    if (present(dist)) dist = at_dist(1:nat)
    if (present(lvec)) lvec = at_lvec(:,1:nat)

  contains
    ! Find the indices for the nth shell of blocks. Sets the number of indices (nb),
    ! the indices themselves (idb(3,nb)), and the rmax for this shell (dmax).
    subroutine make_block_shell(n)
      integer, intent(in) :: n

      integer :: i, j, ic

      ! special case: n = 0
      if (n == 0) then
         nb = 1
         if (allocated(idb)) deallocate(idb)
         allocate(idb(3,nb))
         idb = 0
         dmax = 0d0
         return
      end if

      ! allocate space for (2n+1)^3 - (2n-1)^3 blocks
      nb = 2 + 24 * n * n
      if (allocated(idb)) deallocate(idb)
      allocate(idb(3,nb))

      ! list them
      ic = 0
      do i = -n+1, n-1
         do j = -n+1, n-1
            ic = ic + 1
            idb(:,ic) = (/n,i,j/)
            ic = ic + 1
            idb(:,ic) = (/-n,i,j/)

            ic = ic + 1
            idb(:,ic) = (/i,n,j/)
            ic = ic + 1
            idb(:,ic) = (/i,-n,j/)

            ic = ic + 1
            idb(:,ic) = (/i,j,n/)
            ic = ic + 1
            idb(:,ic) = (/i,j,-n/)
         end do
         ic = ic + 1
         idb(:,ic) = (/n,n,i/)
         ic = ic + 1
         idb(:,ic) = (/n,-n,i/)
         ic = ic + 1
         idb(:,ic) = (/-n,n,i/)
         ic = ic + 1
         idb(:,ic) = (/-n,-n,i/)

         ic = ic + 1
         idb(:,ic) = (/n,i,n/)
         ic = ic + 1
         idb(:,ic) = (/n,i,-n/)
         ic = ic + 1
         idb(:,ic) = (/-n,i,n/)
         ic = ic + 1
         idb(:,ic) = (/-n,i,-n/)

         ic = ic + 1
         idb(:,ic) = (/i,n,n/)
         ic = ic + 1
         idb(:,ic) = (/i,n,-n/)
         ic = ic + 1
         idb(:,ic) = (/i,-n,n/)
         ic = ic + 1
         idb(:,ic) = (/i,-n,-n/)
      end do

      ic = ic + 1
      idb(:,ic) = (/n,n,n/)
      ic = ic + 1
      idb(:,ic) = (/n,n,-n/)
      ic = ic + 1
      idb(:,ic) = (/n,-n,n/)
      ic = ic + 1
      idb(:,ic) = (/n,-n,-n/)
      ic = ic + 1
      idb(:,ic) = (/-n,n,n/)
      ic = ic + 1
      idb(:,ic) = (/-n,n,-n/)
      ic = ic + 1
      idb(:,ic) = (/-n,-n,n/)
      ic = ic + 1
      idb(:,ic) = (/-n,-n,-n/)

      ! calculate the radius of the largest sphere contained in the blocked
      ! region (dmax)
      dmax = 0.5d0 * c%blockomega / maxval(c%blockcv / real(n,8))

    end subroutine make_block_shell

    ! add current atom (idx) to the output list
    subroutine add_atom_to_output_list()
      nat = nat + 1
      if (nat > size(at_id,1)) then
         call realloc(at_id,2*nat)
         call realloc(at_dist,2*nat)
         call realloc(at_lvec,3,2*nat)
      end if
      at_id(nat) = idx
      at_dist(nat) = dd
      if (c%ismolecule) then
         at_lvec(:,nat) = 0
      else
         at_lvec(:,nat) = nint(c%xr2x(xr) - c%atcel(idx)%x)
      end if
    end subroutine add_atom_to_output_list

    subroutine add_shell_to_output_list()
      use types, only: realloc

      integer :: i, ithis

      do i = 1, nshel
         if (abs(rshel(i) - dd) < shell_eps) return
      end do
      nshel = nshel + 1
      if (nshel > size(rshel,1)) call realloc(rshel,2*nshel)
      rshel(nshel) = dd

    end subroutine add_shell_to_output_list

  end subroutine list_near_atoms

  !> Given the point xp (in icrd coordinates), calculate the
  !> nearest atom up to a distance distmax (or up to infinity, if no
  !> distmax is given). The nearest atom has ID nid from the complete
  !> list (atcel) and is at a distance dist, or nid=0 and dist=distmax
  !> if the search did not produce any atoms up to distmax. On output,
  !> the optional argument lvec contains the lattice vector to the
  !> nearest atom (i.e. its position is atcel(nid)%x + lvec).
  !> Optional input:
  !> - nid0 = consider only atoms with index nid0 from the nneq list.
  !> - id0 = consider only atoms with index id0 from the complete list.
  !> - iz0 = consider only atoms with atomic number iz0.
  !> - ispc0 = consider only species with species ID ispc0.
  !> - nozero = disregard zero-distance atoms.
  !>
  !> This routine is thread-safe.
  module subroutine nearest_atom_env(c,xp,icrd,nid,dist,distmax,lvec,nid0,id0,iz0,ispc0,nozero)
    class(crystal), intent(inout) :: c
    real*8, intent(in) :: xp(3)
    integer, intent(in) :: icrd
    integer, intent(out) :: nid
    real*8, intent(out) :: dist
    real*8, intent(in), optional :: distmax
    integer, intent(out), optional :: lvec(3)
    integer, intent(in), optional :: nid0
    integer, intent(in), optional :: id0
    integer, intent(in), optional :: iz0
    integer, intent(in), optional :: ispc0
    logical, intent(in), optional :: nozero

    integer :: nat
    integer, allocatable :: eid(:), lvec_(:,:)
    real*8, allocatable :: dist_(:)

    ! get just one atom
    call c%list_near_atoms(xp,icrd,.false.,nat,eid=eid,dist=dist_,lvec=lvec_,up2n=1,&
       nid0=nid0,id0=id0,iz0=iz0,ispc0=ispc0,nozero=nozero)

    ! if no atoms in output, return
    nid = 0
    dist = huge(1d0)
    if (nat == 0) return

    ! if the distance is higher than distmax, return
    if (present(distmax)) then
       if (dist_(1) > distmax) then
          dist = distmax
          return
       end if
    end if

    ! write and finish
    nid = eid(1)
    dist = dist_(1)
    if (present(lvec)) lvec = lvec_(:,1)

  end subroutine nearest_atom_env

end submodule env
