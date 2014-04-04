AC_INIT([worker], [1.4], [geertjan.bex@uhasselt.be])
AM_INIT_AUTOMAKE([-Wall -Werror foreign tar-pax])
AC_PROG_CC([mpicc])
AC_CHECK_HEADERS([stdlib.h])
AC_CHECK_HEADERS([string.h])
AC_CHECK_HEADERS([unistd.h])
AC_CONFIG_FILES([
    Makefile
    src/Makefile
    src/perl/Makefile
    src/perl/Pbs/Makefile
    src/perl/Worker/Makefile
    src/tt/Makefile
    conf/Makefile
    doc/Makefile
])
AC_OUTPUT

