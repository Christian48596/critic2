! Copyright (c) 2015 Alberto Otero de la Roza <alberto@fluor.quimica.uniovi.es>,
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

!> Dirty hacks for dirty jobs. Abandon hope all ye who enter here.
module tricks
  implicit none

  private
  public :: trick

contains

  subroutine trick(line0)
    use tools_io
    use struct_basic
    character*(*), intent(in) :: line0

    integer :: i, j, ii, jj, nn, i3
    integer :: lu, idx, idx1, idx2
    character(len=:), allocatable :: line, str
    logical :: ok
    real*8 :: a1, a2, maxc6, rmax, rmax2, x(3), ri, ri2, ri3
    real*8 :: cn0, rvdwx, rix, exx, eat, etotal
    real*8 :: c6(cr%ncel,cr%ncel), c8(cr%ncel,cr%ncel), c10(cr%ncel,cr%ncel)
    real*8 :: rc(cr%ncel,cr%ncel), rvdw(cr%ncel,cr%ncel)
    
    real*8, parameter :: ecut = 1d-11

    write (uout,'("* Trick: sum the XDM dispersion energy")')
    write (uout,'("+ Reading coefficients from the file: ",A)') string(cr%file)

    lu = fopen_read(string(cr%file))
    call cr%build_env(.false.,150d0)

    main: do while (getline(lu,line))
       ! read the parameters
       if (trim(line) == "* XDM dispersion") then
          ok = getline(lu,line)
          idx = index(line,"=")
          str = trim(line(idx+1:))
          read(str,*) a1
          ok = getline(lu,line)
          ok = getline(lu,line)
          idx = index(line,"=")
          str = trim(line(idx+1:))
          read(str,*) a2
       end if
       ! read the dispersion coefficients and the radii
       if (trim(line) == "+ Dispersion coefficients") then
          do i = 1, cr%ncel
             do j = 1, i
                ok = getline(lu,line)
                read(line,*) idx1, idx2, c6(i,j), c8(i,j), c10(i,j), rc(i,j), rvdw(i,j)
                if (idx1 /= i .or. idx2 /= j) then
                   write (*,*) idx1, i
                   write (*,*) idx2, j
                   call ferror("trick","read indices do not match",faterr)
                end if
                c6(j,i) = c6(i,j)
                c8(j,i) = c8(i,j)
                c10(j,i) = c10(i,j)
                rc(j,i) = rc(i,j)
                rvdw(j,i) = rvdw(i,j)
             end do
          end do
       end if
    end do main
    call fclose(lu)

    ! do stuff
    do i = 1, cr%ncel
       if (cr%atcel(i)%x(3) < 0.25d0) then
          c6(i,:) = 0d0
          c6(:,i) = 0d0
          c8(i,:) = 0d0
          c8(:,i) = 0d0
          c10(i,:) = 0d0
          c10(:,i) = 0d0
       endif
    end do

    ! calculate the energy
    maxc6 = maxval(c6)
    ! set the atomic environment for the sum
    rmax = (maxc6/ecut)**(1d0/6d0)
    rmax2 = rmax*rmax
    etotal = 0d0
    do i = 1, cr%ncel
       eat = 0d0
       do jj = 1, cr%nenv
          j = cr%atenv(jj)%cidx
          x = cr%atenv(jj)%r - cr%atcel(i)%r
          ri2 = x(1)*x(1) + x(2)*x(2) + x(3)*x(3)
          if (ri2 < 1d-15 .or. ri2>rmax2) cycle
          ri = sqrt(ri2)
          ri3 = ri2 * ri
    
          do nn = 6, 10, 2
             ! order R^nn
             i3 = nn / 2 - 1
    
             ! check the ii and the jj, also how the env is generated
             if (nn == 6) then
                cn0 = c6(i,j)
             elseif (nn == 8) then
                cn0 = c8(i,j)
             elseif (nn == 10) then
                cn0 = c10(i,j)
             end if
    
             ! energy contribution
             rvdwx = rvdw(i,j)**nn
             rix = ri**nn
             exx = cn0 / (rvdwx + rix)
             eat = eat + exx
          end do
       end do ! jj
       etotal = etotal + eat 
    end do ! ii
    etotal= -0.5d0 * etotal
    
    write (uout,'("  Evdw = ",A," Hartree, ",A," Ry")') &
       string(etotal,'e',decimal=10), string(etotal*2,'e',decimal=10)
    
    write (uout,*)

  end subroutine trick

end module tricks
