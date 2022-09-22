! Copyright (c) 2019-2022 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

! OpenGL shader programs
module shaders
  use iso_c_binding
  implicit none

  private

  integer, parameter, public :: shader_test = 1
  integer, parameter, public :: shader_phong = 2
  integer, parameter, public :: shader_NUM = 2
  integer(c_int), public :: ishad_prog(shader_NUM)

  public :: shaders_init
  public :: shaders_end

  ! module procedure interfaces
  interface
     module subroutine shaders_init()
     end subroutine shaders_init
     module subroutine shaders_end()
     end subroutine shaders_end
  end interface

end module shaders
