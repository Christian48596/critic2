! Copyright (c) 2007-2018 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

submodule (hirshfeld) proc
  implicit none

  integer, parameter :: mprops = 1

contains

  ! calculate hirshfeld charges using a grid
  module subroutine hirsh_props_grid()
    use systemmod, only: sy
    use grid3mod, only: grid3
    use grid1mod, only: grid1, agrid
    use fieldmod, only: type_grid
    use tools_io, only: ferror, faterr, uout, string, ioj_center

    integer :: i, j, k
    real*8 :: dist, rrho, rrho1, rrho2, x(3), xdelta(3,3)
    integer :: n(3)
    logical :: doagain
    integer :: ishl, il, ill, ivec(3), iat
    real*8 :: lvec(3), sum, qtotal, qerr, qat(sy%c%nneq)
    type(grid3) :: hw

    if (sy%f(sy%iref)%type /= type_grid) &
       call ferror("hirsh_props_grid","grid hirshfeld only for grid interface",faterr)

    write (uout,'("* Hirshfeld atomic charges")')
    write (uout,'("  Promolecular density grid size: ",3(A,X))') (string(sy%f(sy%iref)%grid%n(j)),j=1,3)


    n = sy%f(sy%iref)%grid%n
    call sy%c%promolecular_grid(hw,n)

    do i = 1, 3
       xdelta(:,i) = 0d0
       xdelta(i,i) = 1d0 / real(n(i),8)
       xdelta(:,i) = sy%c%x2c(xdelta(:,i))
    end do

    ! parallelize over atoms
    qtotal = 0d0
    qerr = 0d0
    qat = 0d0
    !$omp parallel do private (doagain,ishl,sum,ill,ivec,lvec,x,dist,rrho,rrho1,rrho2)
    do iat = 1, sy%c%nneq
       doagain = .true.
       ishl = -1
       sum = 0d0
       do while(doagain)
          doagain = .false.
          ishl = ishl+1

          do il = 0, (2*ishl+1)**3-1
             ill = il
             ivec(1) = mod(ill,2*ishl+1)-ishl
             ill = ill / (2*ishl+1)
             ivec(2) = mod(ill,2*ishl+1)-ishl
             ill = ill / (2*ishl+1)
             ivec(3) = mod(ill,2*ishl+1)-ishl

             if (all(abs(ivec) /= ishl)) cycle

             lvec = sy%c%x2c(real(ivec,8))

             do k = 1, n(3)
                do j = 1, n(2)
                   do i = 1, n(1)
                      x = lvec + (i-1) * xdelta(:,1) + (j-1) * xdelta(:,2) + &
                         (k-1) * xdelta(:,3) - sy%c%at(iat)%r
                      dist = norm2(x)
                      if (.not.agrid(sy%c%spc(sy%c%at(iat)%is)%z)%isinit) cycle
                      if (dist > agrid(sy%c%spc(sy%c%at(iat)%is)%z)%rmax / 2) cycle

                      doagain = .true.
                      call agrid(sy%c%spc(sy%c%at(iat)%is)%z)%interp(dist,rrho,rrho1,rrho2)
                      sum = sum + rrho / hw%f(i,j,k) * sy%f(sy%iref)%grid%f(i,j,k)
                   end do
                end do
             end do
          end do
       end do

       sum = sum * sy%c%omega / real(n(1)*n(2)*n(3),8)
       !$omp critical (io)
       qat(iat) = sum
       qtotal = qtotal + sum * sy%c%at(iat)%mult
       qerr = qerr + (sy%f(sy%iref)%zpsp(sy%c%spc(sy%c%at(iat)%is)%z)-sum) * sy%c%at(iat)%mult
       !$omp end critical (io)
    end do
    !$omp end parallel do
    write (uout,'("# i  Atom Charge")')
    do iat = 1, sy%c%nneq
       write (uout,'(3(A,X))') string(iat,length=4,justify=ioj_center), &
          string(sy%c%spc(sy%c%at(iat)%is)%name,length=5,justify=ioj_center), &
          string(sy%f(sy%iref)%zpsp(sy%c%spc(sy%c%at(iat)%is)%z)-qat(iat),'f',length=16,decimal=10,justify=3)
    end do
    write (uout,'("# total integrated charge: ",A)') string(qtotal,'e',decimal=10)
    write (uout,'("# error integrated charge: ",A)') string(qerr,'e',decimal=10)
    write (uout,*)

  end subroutine hirsh_props_grid

end submodule proc
