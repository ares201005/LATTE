!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! COPYRIGHT 2010.  LOS ALAMOS NATIONAL SECURITY, LLC. THIS MATERIAL WAS    !
! PRODUCED UNDER U.S. GOVERNMENT CONTRACT DE-AC52-06NA25396 FOR LOS ALAMOS !
! NATIONAL LABORATORY (LANL), WHICH IS OPERATED BY LOS ALAMOS NATIONAL     !
! SECURITY, LLC FOR THE U.S. DEPARTMENT OF ENERGY. THE U.S. GOVERNMENT HAS !
! RIGHTS TO USE, REPRODUCE, AND DISTRIBUTE THIS SOFTWARE.  NEITHER THE     !
! GOVERNMENT NOR LOS ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY,     !
! EXPRESS OR IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS         !
! SOFTWARE.  IF SOFTWARE IS MODIFIED TO PRODUCE DERIVATIVE WORKS, SUCH     !
! MODIFIED SOFTWARE SHOULD BE CLEARLY MARKED, SO AS NOT TO CONFUSE IT      !
! WITH THE VERSION AVAILABLE FROM LANL.                                    !
!                                                                          !
! ADDITIONALLY, THIS PROGRAM IS FREE SOFTWARE; YOU CAN REDISTRIBUTE IT     !
! AND/OR MODIFY IT UNDER THE TERMS OF THE GNU GENERAL PUBLIC LICENSE AS    !
! PUBLISHED BY THE FREE SOFTWARE FOUNDATION; VERSION 2.0 OF THE LICENSE.   !
! ACCORDINGLY, THIS PROGRAM IS DISTRIBUTED IN THE HOPE THAT IT WILL BE     !
! USEFUL, BUT WITHOUT ANY WARRANTY; WITHOUT EVEN THE IMPLIED WARRANTY OF   !
! MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. SEE THE GNU GENERAL !
! PUBLIC LICENSE FOR MORE DETAILS.                                         !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!> To apply the sp2 method using the progress library.
!! \brief This is a special interface to apply the sp2 solvers from
!! the progress library.
!! \brief See https://github.com/losalamos/qmd-progress
!!
MODULE SP2PROGRESS

#ifdef PROGRESSON
  USE BML
  USE PRG_SP2_MOD
  USE PRG_SP2PARSER_MOD

  USE SETUPARRAY
  USE MDARRAY
  USE PUREARRAY
  USE NONOARRAY
  USE CONSTANTS_MOD
  USE NONOARRAY
  USE MYPRECISION
#endif

  PRIVATE

  PUBLIC :: SP2PRG

#ifdef PROGRESSON
  LOGICAL, PUBLIC                           :: SP2INIT = .FALSE.!COUTER TO KEEP TRACK OF THE TIMES ZMAT IS COMPUTED.
  TYPE(BML_MATRIX_T)                        :: ORTHOH_BML, ORTHOX_BML
  TYPE(SP2DATA_TYPE), PUBLIC                :: SP2D
#endif

CONTAINS

  !> This routine implements the sp2 thechnique with the
  !! routines of the progress library.
  !!
  SUBROUTINE SP2PRG()
    IMPLICIT NONE

#ifdef PROGRESSON

    !> Parsing sp2 input paramenters. this will read the variables in the input file.
    !  sp2 is the "SP2DATA_TYPE".
    IF(.NOT.SP2INIT)THEN
       CALL PRG_PARSE_SP2(SP2D,"latte.in")
       SP2INIT = .TRUE.
    ENDIF

    IF(SP2D%MDIM < 0)SP2D%MDIM = HDIM

    !! Convert Hamiltonian to bml format
    !! H should be in orthogonal form, ORTHOH
    CALL BML_ZERO_MATRIX(BML_MATRIX_ELLPACK, BML_ELEMENT_REAL, &
         LATTEPREC, HDIM, SP2D%MDIM, ORTHOH_BML)
    CALL BML_ZERO_MATRIX(BML_MATRIX_ELLPACK, BML_ELEMENT_REAL, &
         LATTEPREC, HDIM, SP2D%MDIM, ORTHOX_BML)
    CALL BML_IMPORT_FROM_DENSE(BML_MATRIX_ELLPACK, &
         ORTHOH, ORTHOH_BML, ZERO, SP2D%MDIM)

    !! Perform SP2 from progress
    IF(SP2D%FLAVOR.EQ."Basic")THEN
       CALL PRG_SP2_BASIC(ORTHOH_BML,ORTHOX_BML,SP2D%THRESHOLD, BNDFIL, SP2D%MINSP2ITER, SP2D%MAXSP2ITER &
            ,SP2D%SP2CONV,SP2D%SP2TOL,SP2D%VERBOSE)
    ELSEIF(SP2D%FLAVOR.EQ."Alg1")THEN
       CALL PRG_SP2_ALG1(ORTHOH_BML,ORTHOX_BML,SP2D%THRESHOLD, BNDFIL, SP2D%MINSP2ITER, SP2D%MAXSP2ITER &
            ,SP2D%SP2CONV,SP2D%SP2TOL,SP2D%VERBOSE)
    ELSEIF(SP2D%FLAVOR.EQ."Alg2")THEN
       CALL PRG_SP2_ALG2(ORTHOH_BML,ORTHOX_BML,SP2D%THRESHOLD, BNDFIL, SP2D%MINSP2ITER, SP2D%MAXSP2ITER &
            ,SP2D%SP2CONV,SP2D%SP2TOL,SP2D%VERBOSE)
    ELSE
       CALL ERRORS("sp2progress","No valid SP2 flavor")
    ENDIF

    ! CALL BML_PRINT_MATRIX("ORTHOP",ORTHOX_BML,1,10,1,10)

    !! Convert orthogonal density bml matrix back to dense
    !! BO will be converted to nonorthogonal after this call
    CALL BML_EXPORT_TO_DENSE(ORTHOX_BML, BO)

    CALL BML_DEALLOCATE(ORTHOH_BML)
    CALL BML_DEALLOCATE(ORTHOX_BML)

#endif

  END SUBROUTINE SP2PRG

END MODULE SP2PROGRESS