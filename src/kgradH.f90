!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Copyright 2010.  Los Alamos National Security, LLC. This material was    !
! produced under U.S. Government contract DE-AC52-06NA25396 for Los Alamos !
! National Laboratory (LANL), which is operated by Los Alamos National     !
! Security, LLC for the U.S. Department of Energy. The U.S. Government has !
! rights to use, reproduce, and distribute this software.  NEITHER THE     !
! GOVERNMENT NOR LOS ALAMOS NATIONAL SECURITY, LLC MAKES ANY WARRANTY,     !
! EXPRESS OR IMPLIED, OR ASSUMES ANY LIABILITY FOR THE USE OF THIS         !
! SOFTWARE.  If software is modified to produce derivative works, such     !
! modified software should be clearly marked, so as not to confuse it      !
! with the version available from LANL.                                    !
!                                                                          !
! Additionally, this program is free software; you can redistribute it     !
! and/or modify it under the terms of the GNU General Public License as    !
! published by the Free Software Foundation; version 2.0 of the License.   !
! Accordingly, this program is distributed in the hope that it will be     !
! useful, but WITHOUT ANY WARRANTY; without even the implied warranty of   !
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General !
! Public License for more details.                                         !
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

SUBROUTINE KGRADH

  USE CONSTANTS_MOD
  USE SETUPARRAY
  USE NEBLISTARRAY
  USE UNIVARRAY
  USE SPINARRAY
  USE VIRIALARRAY
  USE KSPACEARRAY
  USE MYPRECISION

  IMPLICIT NONE

  INTEGER :: I, J, K, L, M, N, KK, INDI, INDJ
  INTEGER :: LBRA, MBRA, LKET, MKET
  INTEGER :: PREVJ, NEWJ
  INTEGER :: PBCI, PBCJ, PBCK
  INTEGER :: BASISI(5), BASISJ(5), LBRAINC, LKETINC
  INTEGER :: KX, KY, KZ, KCOUNT
  REAL(LATTEPREC) :: ALPHA, BETA, PHI, COSBETA
  REAL(LATTEPREC) :: RIJ(3), DC(3)
  REAL(LATTEPREC) :: MAGR, MAGR2, MAGRP, MAGRP2
  REAL(LATTEPREC) :: MAXARRAY(20), MAXRCUT, MAXRCUT2
  REAL(LATTEPREC) :: MYDFDA, MYDFDB, MYDFDR, RCUTTB, TMPVAL
  REAL(LATTEPREC) :: KPOINT(3), KX0, KY0, KZ0, KDOTL
  REAL(LATTEPREC) :: B1(3), B2(3), B3(3), MAG1, MAG2, MAG3, A1A2XA3, K0(3)
  REAL(LATTEPREC), EXTERNAL :: DFDA, DFDB, DFDR
  COMPLEX(LATTEPREC) :: FTMP(3), RHO, CONJGBLOCH
  LOGICAL PATH
  IF (EXISTERROR) RETURN

  KF = CMPLX(ZERO)
  VIRBONDK = CMPLX(ZERO)

  ! Computing the reciprocal lattice vectors

  B1(1) = BOX(2,2)*BOX(3,3) - BOX(3,2)*BOX(2,3)
  B1(2) = BOX(3,1)*BOX(2,3) - BOX(2,1)*BOX(3,3)
  B1(3) = BOX(2,1)*BOX(3,2) - BOX(3,1)*BOX(2,2)

  A1A2XA3 = BOX(1,1)*B1(1) + BOX(1,2)*B1(2) + BOX(1,3)*B1(3)

  ! B1 = 2*PI*(A2 X A3)/(A1.(A2 X A3))

  B1 = TWO*PI*B1/A1A2XA3

  ! B2 = 2*PI*(A3 x A1)/(A1(A2 X A3))

  B2(1) = (BOX(3,2)*BOX(1,3) - BOX(1,2)*BOX(3,3))/A1A2XA3
  B2(2) = (BOX(1,1)*BOX(3,3) - BOX(3,1)*BOX(1,3))/A1A2XA3
  B2(3) = (BOX(3,1)*BOX(1,2) - BOX(1,1)*BOX(3,2))/A1A2XA3

  B2 = TWO*PI*B2

  ! B3 = 2*PI*(A1 x A2)/(A1(A2 X A3))

  B3(1) = (BOX(1,2)*BOX(2,3) - BOX(2,2)*BOX(1,3))/A1A2XA3
  B3(2) = (BOX(2,1)*BOX(1,3) - BOX(1,1)*BOX(2,3))/A1A2XA3
  B3(3) = (BOX(1,1)*BOX(2,2) - BOX(2,1)*BOX(1,2))/A1A2XA3

  B3 = TWO*PI*B3

!  K0 = PI*KSHIFT

!$OMP PARALLEL DO DEFAULT (NONE) &
!$OMP SHARED(NATS, BASIS, ELEMPOINTER, TOTNEBTB, NEBTB) &
!$OMP SHARED(CR, BOX, KBO, SPINON) &
!$OMP SHARED(KRHOUP, KRHODOWN)&  
!$OMP SHARED(HCUT, SCUT, MATINDLIST, BASISTYPE, ORBITAL_LIST, CUTOFF_LIST) &
!$OMP SHARED(K0, B1, B2, B3, NKX, NKY, NKZ, KF) &
!$OMP PRIVATE(I, J, K, NEWJ, BASISI, BASISJ, INDI, INDJ, PBCI, PBCJ, PBCK) &
!$OMP PRIVATE(RIJ, MAGR2, MAGR, MAGRP2, MAGRP, PATH, PHI, ALPHA, BETA, COSBETA, FTMP) &
!$OMP PRIVATE(DC, LBRAINC, LBRA, MBRA, L, LKETINC, LKET, MKET, RHO) &
!$OMP PRIVATE(MYDFDA, MYDFDB, MYDFDR, CONJGBLOCH, KDOTL, RCUTTB, TMPVAL) &
!$OMP PRIVATE(KPOINT, KCOUNT) &
!$OMP REDUCTION(+: VIRBONDK)

  DO I = 1, NATS

     ! Build list of orbitals on atom I

     BASISI(:) = ORBITAL_LIST(:,I)

     ! find the right place in the array

     INDI = MATINDLIST(I)

     DO NEWJ = 1, TOTNEBTB(I)

        J = NEBTB(1, NEWJ, I)
        PBCI = NEBTB(2, NEWJ, I)
        PBCJ = NEBTB(3, NEWJ, I)
        PBCK = NEBTB(4, NEWJ, I)

        RIJ(1) = CR(1,J) + REAL(PBCI)*BOX(1,1) + REAL(PBCJ)*BOX(2,1) + &
             REAL(PBCK)*BOX(3,1) - CR(1,I)

        RIJ(2) = CR(2,J) + REAL(PBCI)*BOX(1,2) + REAL(PBCJ)*BOX(2,2) + &
             REAL(PBCK)*BOX(3,2) - CR(2,I)

        RIJ(3) = CR(3,J) + REAL(PBCI)*BOX(1,3) + REAL(PBCJ)*BOX(2,3) + &
             REAL(PBCK)*BOX(3,3) - CR(3,I)

        MAGR2 = RIJ(1)*RIJ(1) + RIJ(2)*RIJ(2) + RIJ(3)*RIJ(3)

        ! Building the forces is expensive - use the cut-off

        RCUTTB = CUTOFF_LIST(J,I)

        IF (MAGR2 .LT. RCUTTB*RCUTTB) THEN

           MAGR = SQRT(MAGR2)
           !                    IF (MAGR .LT. 2.5) PRINT*, "Short bond"

           BASISJ(:) = ORBITAL_LIST(:,J)

           INDJ = MATINDLIST(J)

           MAGRP2 = RIJ(1)*RIJ(1) + RIJ(2)*RIJ(2)
           MAGRP = SQRT(MAGRP2)

           ! transform to system in which z-axis is aligned with RIJ

           PATH = .FALSE.
           IF (ABS(RIJ(1)) .GT. 1E-12) THEN
              IF (RIJ(1) .GT. ZERO .AND. RIJ(2) .GE. ZERO) THEN
                 PHI = ZERO
              ELSEIF (RIJ(1) .GT. ZERO .AND. RIJ(2) .LT. ZERO) THEN
                 PHI = TWO * PI
              ELSE
                 PHI = PI
              ENDIF
              ALPHA = ATAN(RIJ(2) / RIJ(1)) + PHI
           ELSEIF (ABS(RIJ(2)) .GT. 1E-12) THEN
              IF (RIJ(2) .GT. 1E-12) THEN
                 ALPHA = PI / TWO
              ELSE
                 ALPHA = THREE * PI / TWO
              ENDIF
           ELSE
              ! pathological case: pole in alpha at beta=0
              PATH = .TRUE.
           ENDIF

           COSBETA = RIJ(3) / MAGR
           BETA = ACOS( COSBETA )

           !        PRINT*, ALPHA, BETA

           DC = RIJ/MAGR

           ! build forces using PRB 72 165107 eq. (12) - the sign of the
           ! dfda contribution seems to be wrong, but gives the right
           ! answer(?)

           FTMP = CMPLX(ZERO)
           K = INDI

           LBRAINC = 1
           DO WHILE (BASISI(LBRAINC) .NE. -1)

              LBRA = BASISI(LBRAINC)
              LBRAINC = LBRAINC + 1

              DO MBRA = -LBRA, LBRA

                 K = K + 1
                 L = INDJ

                 LKETINC = 1
                 DO WHILE (BASISJ(LKETINC) .NE. -1)

                    LKET = BASISJ(LKETINC)
                    LKETINC = LKETINC + 1

                    DO MKET = -LKET, LKET

                       L = L + 1

                       IF (.NOT. PATH) THEN

                          ! Unroll loops and pre-compute

                          CALL DFDX(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, ALPHA, COSBETA, "H", &
                               MYDFDA, MYDFDB, MYDFDR)
                          

                          !
                          ! d/d_alpha
                          !

                          KCOUNT = 0

                          DO KX = 1, NKX

                             DO KY = 1, NKY

                                DO KZ = 1, NKZ

                                   KPOINT = ZERO
                                   KPOINT = KPOINT + (TWO*REAL(KX) - REAL(NKX) - ONE)/(TWO*REAL(NKX))*B1
                                   KPOINT = KPOINT + (TWO*REAL(KY) - REAL(NKY) - ONE)/(TWO*REAL(NKY))*B2
                                   KPOINT = KPOINT + (TWO*REAL(KZ) - REAL(NKZ) - ONE)/(TWO*REAL(NKZ))*B3

                                   KCOUNT = KCOUNT+1

                                   KDOTL = KPOINT(1)*RIJ(1) + KPOINT(2)*RIJ(2) + &
                                        KPOINT(3)*RIJ(3)

                                   CONJGBLOCH = EXP(CMPLX(ZERO,-KDOTL))

                                   SELECT CASE(SPINON)
                                   CASE(0)
                                      RHO = KBO(K,L, KCOUNT)
                                   CASE(1)
                                      RHO = KRHOUP(K,L,KCOUNT) + KRHODOWN(K,L,KCOUNT)
                                   END SELECT



                                   FTMP(1) = FTMP(1) + RHO * &
                                        (-RIJ(2) / MAGRP2 * MYDFDA)*CONJGBLOCH

                                   FTMP(2) = FTMP(2) + RHO * &
                                        (RIJ(1)/ MAGRP2 * MYDFDA)*CONJGBLOCH

                                   !
                                   ! d/d_beta
                                   !

                                   FTMP(1) = FTMP(1) + RHO * &
                                        (((((RIJ(3) * RIJ(1)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)*CONJGBLOCH

                                   FTMP(2) = FTMP(2) + RHO * &
                                        (((((RIJ(3) * RIJ(2)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)*CONJGBLOCH

                                   FTMP(3) = FTMP(3) - RHO * &
                                        (((ONE - ((RIJ(3) * RIJ(3)) / &
                                        MAGR2)) / MAGRP) * MYDFDB)*CONJGBLOCH

                                   !
                                   ! d/dR
                                   !

                                   FTMP(1) = FTMP(1) - RHO * DC(1) * &
                                        MYDFDR*CONJGBLOCH

                                   FTMP(2) = FTMP(2) - RHO * DC(2) * &
                                        MYDFDR*CONJGBLOCH

                                   FTMP(3) = FTMP(3) - RHO * DC(3) * &
                                        MYDFDR*CONJGBLOCH


                                ENDDO
                             ENDDO
                          ENDDO


                       ELSE

                          ! pathological configuration in which beta=0
                          ! or pi => alpha undefined

                          ! Bug fixed: MJC 12/17/13

                          CALL DFDX(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, PI/TWO, COSBETA, "H", &
                               MYDFDA, MYDFDB, MYDFDR)

                          TMPVAL = MYDFDB/MAGR

                          CALL DFDX(I, J, LBRA, LKET, MBRA, &
                               MKET, MAGR, ZERO, COSBETA, "H", &
                               MYDFDA, MYDFDB, MYDFDR)

                          MYDFDB = MYDFDB/MAGR
                          
                          
!                          MYDFDB = DFDB(I, J, LBRA, LKET, MBRA, &
!                               MKET, MAGR, ZERO, COSBETA, "H") / MAGR

!                          MYDFDB = DFDB(I, J, LBRA, LKET, &
!                               MBRA, MKET, MAGR, PI/TWO, COSBETA, "H") / MAGR

!                          MYDFDR = DFDR(I, J, LBRA, LKET, MBRA, &
!                               MKET, MAGR, ZERO, COSBETA, "H")


                          KCOUNT = 0
                          DO KX = 1, NKX

                             DO KY = 1, NKY

                                DO KZ = 1, NKZ

!                                   KPOINT = TWO*PI*(REAL(KX-1)*B1/REAL(NKX) + &
!                                        REAL(KY-1)*B2/REAL(NKY) + &
!                                        REAL(KZ-1)*B3/REAL(NKZ)) + K0
                                   
                                   KPOINT = ZERO
                                   KPOINT = KPOINT + (TWO*REAL(KX) - REAL(NKX) - ONE)/(TWO*REAL(NKX))*B1
                                   KPOINT = KPOINT + (TWO*REAL(KY) - REAL(NKY) - ONE)/(TWO*REAL(NKY))*B2
                                   KPOINT = KPOINT + (TWO*REAL(KZ) - REAL(NKZ) - ONE)/(TWO*REAL(NKZ))*B3

                                   KCOUNT = KCOUNT+1

                                   KDOTL = KPOINT(1)*RIJ(1) + KPOINT(2)*RIJ(2) + &
                                        KPOINT(3)*RIJ(3)

                                   CONJGBLOCH = EXP(CMPLX(ZERO,-KDOTL))

                                   SELECT CASE(SPINON)
                                   CASE(0)
                                      RHO = KBO(K,L, KCOUNT)
                                   CASE(1)
                                      RHO = KRHOUP(K,L,KCOUNT) + KRHODOWN(K,L,KCOUNT)
                                   END SELECT

                                   FTMP(1) = FTMP(1) - RHO * COSBETA * MYDFDB*CONJGBLOCH
                                   FTMP(2) = FTMP(2) - RHO * COSBETA * TMPVAL*CONJGBLOCH
                                   FTMP(3) = FTMP(3) - RHO * COSBETA * MYDFDR*CONJGBLOCH

                                ENDDO
                             ENDDO
                          ENDDO

                       ENDIF

                    ENDDO
                 ENDDO
              ENDDO
           ENDDO

           KF(1,I) = KF(1,I) + FTMP(1)
           KF(2,I) = KF(2,I) + FTMP(2)
           KF(3,I) = KF(3,I) + FTMP(3)

           VIRBONDK(1) = VIRBONDK(1) +  RIJ(1) * FTMP(1)
           VIRBONDK(2) = VIRBONDK(2) +  RIJ(2) * FTMP(2)
           VIRBONDK(3) = VIRBONDK(3) +  RIJ(3) * FTMP(3)
           VIRBONDK(4) = VIRBONDK(4) +  RIJ(1) * FTMP(2)
           VIRBONDK(5) = VIRBONDK(5) +  RIJ(2) * FTMP(3)
           VIRBONDK(6) = VIRBONDK(6) +  RIJ(3) * FTMP(1)

        ENDIF

     ENDDO

  ENDDO
!$OMP END PARALLEL DO


  !  PRINT *, KF(1,1)/REAL(NKTOT)
  F = REAL(KF)/REAL(NKTOT)
  VIRBOND = REAL(VIRBONDK)/REAL(NKTOT)

  RETURN

END SUBROUTINE KGRADH