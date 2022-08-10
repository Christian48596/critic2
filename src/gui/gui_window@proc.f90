! Copyright (c) 2019 Alberto Otero de la Roza <aoterodelaroza@gmail.com>,
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

! Some utilities for building the GUI (e.g. wrappers around ImGui routines).
submodule (gui_window) proc
  use gui_interfaces_cimgui
  implicit none

  ! Count ID for keeping track of windows and widgets
  integer :: idcount = 0

contains

  !> Initialize a window of the given type. If isiopen, initialize it
  !> as open.
  module subroutine window_init(w,type,isopen)
    class(window), intent(inout) :: w
    integer, intent(in) :: type
    logical, intent(in) :: isopen

    w%isinit = .true.
    w%isopen = isopen
    w%type = type
    w%id = -1

  end subroutine window_init

  !> Draw an ImGui window.
  module subroutine window_draw(w)
    use tools_io, only: string
    class(window), intent(inout), target :: w

    character(kind=c_char,len=:), allocatable, target :: str

    ! First pass: assign ID, name, and flags
    if (w%id < 0) then
       idcount = idcount + 1
       w%id = idcount
       if (w%type == wintype_tree) then
          ! w%name = "Tree###" // string(w%id) // c_null_char
          w%name = "Tree" // c_null_char
          w%flags = ImGuiWindowFlags_None
       elseif (w%type == wintype_view) then
          ! w%name = "View###" // string(w%id) // c_null_char
          w%name = "View" // c_null_char
          w%flags = ImGuiWindowFlags_None
       elseif (w%type == wintype_console) then
          ! w%name = "Console###" // string(w%id) // c_null_char
          w%name = "Console" // c_null_char
          w%flags = ImGuiWindowFlags_None
       end if
    end if

    if (w%isopen) then
       if (igBegin(c_loc(w%name),w%isopen,w%flags)) then
          ! assign the pointer ID
          w%ptr = igGetCurrentWindow()

          ! draw the window contents, depending on type
          if (w%type == wintype_tree) then
             call w%draw_tree()
          elseif (w%type == wintype_view) then
             str = "Hello View!"
             call igText(c_loc(str))
          elseif (w%type == wintype_console) then
             str = "Hello Console!"
             call igText(c_loc(str))
          end if
       end if
       call igEnd()
    end if

  end subroutine window_draw

  !> Draw the contents of a tree window
  module subroutine draw_tree(w)
    use gui_main, only: nsys, sys, sys_status, sys_empty, sys_init, sys_loaded_not_init,&
       sys_seed, system_initialize
    use gui_keybindings, only: is_bind_event, BIND_TREE_MOVE_UP, BIND_TREE_MOVE_DOWN
    use tools_io, only: string
    use param, only: bohrtoa
    class(window), intent(inout), target :: w

    character(kind=c_char,len=:), allocatable, target :: str
    type(ImVec2) :: zero2
    integer(c_int) :: mycol_id, flags
    integer :: i, j, nshown
    logical(c_bool) :: ldum, selected
    logical :: sysupdated
    type(c_ptr) :: ptrc
    type(ImGuiTableSortSpecs), pointer :: sortspecs
    type(ImGuiTableColumnSortSpecs), pointer :: colspecs
    ! column ids
    integer(c_int), parameter :: ic_id = 0
    integer(c_int), parameter :: ic_name = 1
    integer(c_int), parameter :: ic_spg = 2
    integer(c_int), parameter :: ic_v = 3
    integer(c_int), parameter :: ic_nneq = 4
    integer(c_int), parameter :: ic_ncel = 5
    integer(c_int), parameter :: ic_nmol = 6
    integer(c_int), parameter :: ic_a = 7
    integer(c_int), parameter :: ic_b = 8
    integer(c_int), parameter :: ic_c = 9
    integer(c_int), parameter :: ic_alpha = 10
    integer(c_int), parameter :: ic_beta = 11
    integer(c_int), parameter :: ic_gamma = 12

    ! two zeros
    zero2%x = 0
    zero2%y = 0

    ! initialize table
    if (.not.allocated(w%iord)) call w%update_tree()
    nshown = size(w%iord,1)

    ! process keybindings
    if (igIsWindowFocused(0_c_int)) then
       if (is_bind_event(BIND_TREE_MOVE_UP)) then
          w%table_selected = max(w%table_selected-1,1)
       elseif (is_bind_event(BIND_TREE_MOVE_DOWN)) then
          w%table_selected = min(w%table_selected+1,nshown)
       end if
    end if

    ! initialize the currently selected system
    sysupdated = .false.
    if (w%table_selected > 0 .and. w%table_selected <= nshown) then
       if (sys_status(w%iord(w%table_selected)) /= sys_init) then
          call system_initialize(w%iord(w%table_selected))
          sysupdated = .true.
       end if
    end if

    ! set up the table
    str = "Structures" // c_null_char
    flags = ImGuiTableFlags_Borders
    flags = ior(flags,ImGuiTableFlags_Resizable)
    flags = ior(flags,ImGuiTableFlags_Reorderable)
    flags = ior(flags,ImGuiTableFlags_Hideable)
    flags = ior(flags,ImGuiTableFlags_Sortable)
    flags = ior(flags,ImGuiTableFlags_SortMulti)
    flags = ior(flags,ImGuiTableFlags_SizingFixedFit)
    if (igBeginTable(c_loc(str),13,flags,zero2,0._c_float)) then
       if (sysupdated) &
          call igTableSetColumnWidthAutoAll(igGetCurrentTable())

       ! set up the columns
       ! ID - name - spg - volume - nneq - ncel - nmol - a - b - c - alpha - beta - gamma
       str = "ID" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultSort
       flags = ior(flags,ImGuiTableColumnFlags_PreferSortDescending)
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_id)

       str = "Name" // c_null_char
       flags = ImGuiTableColumnFlags_WidthStretch
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_name)

       str = "spg" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_spg)

       str = "V(A^3)" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_v)

       str = "nneq" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_nneq)

       str = "ncel" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_ncel)

       str = "nmol" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_nmol)

       str = "a" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_a)

       str = "b" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_b)

       str = "c" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_c)

       str = "alpha" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_alpha)

       str = "beta" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_beta)

       str = "gamma" // c_null_char
       flags = ImGuiTableColumnFlags_DefaultHide
       call igTableSetupColumn(c_loc(str),flags,0.0_c_float,ic_gamma)

       ! sort the data if specs have changed
       ptrc = igTableGetSortSpecs()
       if (c_associated(ptrc)) then
          call c_f_pointer(ptrc,sortspecs)
          if (sortspecs%SpecsDirty .and. nshown > 1) then
             call c_f_pointer(sortspecs%Specs,colspecs)
             ! call sort_table(colspecs%ColumnUserID,colspecs%SortDirection)
             ! xxxx !
             sortspecs%SpecsDirty = .false.
          end if
       end if

       ! draw the header
       call igTableHeadersRow()

       ! draw the rows
       do j = 1, nshown
          i = w%iord(j)
          if (sys_status(i) == sys_empty) cycle
          call igTableNextRow(ImGuiTableRowFlags_None, 0._c_float);

          ! ID
          if (igTableSetColumnIndex(ic_id)) then
             str = string(i) // c_null_char
             flags = ImGuiSelectableFlags_SpanAllColumns
             selected = (w%table_selected==j)
             if (igSelectable_Bool(c_loc(str),selected,flags,zero2)) then
                w%table_selected = j
             end if
          end if

          ! name
          if (igTableSetColumnIndex(ic_name)) then
             str = trim(sys_seed(i)%file) // c_null_char
             call igText(c_loc(str))
          end if

          if (sys_status(i) == sys_init) then
             if (igTableSetColumnIndex(ic_spg)) then ! spg
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                elseif (.not.sys(i)%c%spgavail) then
                   str = "n/a" // c_null_char
                else
                   str = trim(sys(i)%c%spg%international_symbol) // c_null_char
                end if
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_v)) then ! volume
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%omega,'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_nneq)) then ! nneq
                str = string(sys(i)%c%nneq) // c_null_char
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_ncel)) then ! ncel
                str = string(sys(i)%c%ncel) // c_null_char
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_nmol)) then ! nmol
                str = string(sys(i)%c%nmol) // c_null_char
                call igText(c_loc(str))
             end if

             if (igTableSetColumnIndex(ic_a)) then ! a
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%aa(1)*bohrtoa,'f',decimal=4) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_b)) then ! b
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%aa(2)*bohrtoa,'f',decimal=4) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_c)) then ! c
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%aa(3)*bohrtoa,'f',decimal=4) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_alpha)) then ! alpha
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%bb(1),'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_beta)) then ! beta
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%bb(2),'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if
             if (igTableSetColumnIndex(ic_gamma)) then ! gamma
                if (sys(i)%c%ismolecule) then
                   str = "<mol>" // c_null_char
                else
                   str = string(sys(i)%c%bb(3),'f',decimal=2) // c_null_char
                end if
                call igText(c_loc(str))
             end if

          end if

       end do

       call igEndTable()
    end if

  end subroutine draw_tree

  ! Update the table row order. This is used if the systems have changed.
  module subroutine update_tree(w)
    use gui_main, only: sys_status, nsys, sys_empty
    class(window), intent(inout) :: w

    integer :: i, n

    if (allocated(w%iord)) deallocate(w%iord)
    n = count(sys_status(1:nsys) /= sys_empty)
    if (n > 0) then
       allocate(w%iord(n))
       n = 0
       do i = 1, nsys
          if (sys_status(i) /= sys_empty) then
             n = n + 1
             w%iord(n) = i
          end if
       end do
    end if

  end subroutine update_tree

  ! Sort the table row order.
  module subroutine sort_tree(w,cid,dir)
    class(window), intent(inout) :: w
    integer(c_int), intent(in) :: cid, dir

    write (*,*) "here ", cid, dir

  end subroutine sort_tree

  !xx! private procedures

end submodule proc
