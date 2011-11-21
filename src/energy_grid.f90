module energy_grid

  use constants,        only: MAX_LINE_LEN
  use datatypes,        only: list_insert, list_size, list_delete
  use datatypes_header, only: ListReal
  use global
  use output,           only: write_message

contains

!===============================================================================
! UNIONIZED_GRID creates a single unionized energy grid combined from each
! nuclide of each material. Right now, the grid for each nuclide is added into a
! linked list one at a time with an effective insertion sort. Could be done with
! a hash for all energy points and then a quicksort at the end (what hash
! function to use?)
!===============================================================================

  subroutine unionized_grid()

    integer :: i ! index over materials
    integer :: j ! index over nuclides
    type(ListReal), pointer :: list => null()
    type(ListReal), pointer :: current => null()
    type(Material), pointer :: mat => null()
    type(Nuclide),  pointer :: nuc => null()

    message = "Creating unionized energy grid..."
    call write_message(5)

    ! loop over all materials
    do i = 1, n_materials
       mat => materials(i)
       
       ! loop over all nuclides
       do j = 1, mat % n_nuclides
          nuc => nuclides(mat % nuclide(j))

          ! loop over energy points
          call add_grid_points(list, nuc % energy)
       end do
    end do

    ! create allocated array from linked list
    n_grid = list_size(list)
    allocate(e_grid(n_grid))
    current => list
    do i = 1, n_grid
       e_grid(i) = current % data
       current => current % next
    end do

    ! delete linked list
    call list_delete(list)

  end subroutine unionized_grid

!===============================================================================
! ADD_GRID_POINTS adds energy points from the 'energy' array into a linked list
! of points already stored from previous arrays.
!===============================================================================

  subroutine add_grid_points(list, energy)

    type(ListReal), pointer :: list
    real(8), intent(in) :: energy(:)

    integer :: index
    integer :: n
    real(8) :: E
    type(ListReal), pointer :: current => null()
    type(ListReal), pointer :: previous => null()
    type(ListReal), pointer :: head => null()
    type(ListReal), pointer :: tmp => null()

    index = 1
    n = size(energy)

    ! if the original list is empty, we need to allocate the first element and
    ! store first energy point
    if (list_size(list) == 0) then
       allocate(list)
       current => list
       do index = 1, n
          current % data = energy(index)
          if (index == n) then
             current % next => null()
             return
          end if
          allocate(current % next)
          current => current % next
       end do
    end if

    current => list
    head => list

    do while (index <= n)
       E = energy(index)

       ! If we've reached the end of the grid energy list, add the remaining
       ! energy points to the end
       if (.not. associated(current)) then
          ! finish remaining energies
          do while (index <= n)
             allocate(previous % next)
             current => previous % next
             current % data = energy(index)
             previous => current
             index = index + 1
          end do
          current%next => null()
          exit
       end if
       
       if (E < current % data) then
          ! create new element and insert it in energy grid list
          allocate(tmp)
          tmp % data = E
          tmp % next => current
          if (associated(previous)) then
             previous % next => tmp
             previous => tmp
          else
             previous => tmp
             head => previous
          end if
          nullify(tmp)

          ! advance index
          index = index + 1

       elseif (E == current % data) then
          ! found the exact same energy, no need to store duplicates so just
          ! skip and move to next index
          index = index + 1
       else
          previous => current
          current => current % next
       end if
       
    end do

    ! It's possible that an element was inserted at the front of the list, so we
    ! need to move the list pointer back to the start of the list
    list => head

  end subroutine add_grid_points

!===============================================================================
! ORIGINAL_INDICES
!===============================================================================

  subroutine original_indices()

    integer :: i
    integer :: j
    integer :: index
    integer :: n_grid_nuclide
    real(8) :: union_energy
    real(8) :: energy
    type(Nuclide), pointer :: nuc

    do i = 1, n_nuclides_total
       nuc => nuclides(i)
       n_grid_nuclide = size(nuc % energy)
       allocate(nuc % grid_index(n_grid))

       index = 1
       energy = nuc % energy(index)

       do j = 1, n_grid
          union_energy = e_grid(j)
          if (union_energy >= energy .and. index < n_grid_nuclide) then
             index = index + 1
             energy = nuc % energy(index)
          end if
          nuc % grid_index(j) = index-1
       end do
    end do

  end subroutine original_indices

end module energy_grid
