# This Makefile is part of the SCHISM-ESMF interface
#
# SPDX-FileCopyrightText: 2021-2023 Helmholtz-Zentrum Hereon
# SPDX-FileCopyrightText: 2018-2021 Helmholtz-Zentrum Geesthacht
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileContributor: Carsten Lemmen <carsten.lemmen@hereon.de
# SPDX-FileContributor: Richard Hofmeister

include src/include/Rules.mk

DESTDIR?=./lib

ifndef USE_PDAF
ifdef PDAF_LIB_DIR
USE_PDAF=ON
endif
endif

ifeq ($(USE_PDAF),ON)
CPPFLAGS+= -DUSE_PDAF
endif

# @todo parmetis should have been included in lschism_esmf, but
# that does not seem to work cross-platform ...
LIBS+= -lschism_esmf -lesmf
F90FLAGS+= -I$(SCHISM_BUILD_DIR)/include -I src/schism #-r8  ###-I src/model -I src/schism
##PDAF requires MKL (BLAS, LAPACK), this should already be provided by ESMF_FLAGS ...

ifeq ($(USE_PDAF),ON)
LDFLAGS+= -L$(PDAF_LIB_DIR) -lpdaf-d 
endif
ifeq ($(ESMF_COMPILER), intel)
LDFLAGS+=-mkl -lpthread -lm -ldl
LDFLAGS+= -L$(SCHISM_BUILD_DIR)/lib -L. -Wl,--start-group  $(MKLROOT)/lib/intel64/libmkl_intel_lp64.a $(MKLROOT)/lib/intel64/libmkl_intel_thread.a $(MKLROOT)/lib/intel64/libmkl_core.a -Wl,--end-group -qopenmp -lpthread -lm
else
ifeq ($(ESMF_COMPILER), gfortran)
# @todo still some lapack routines missing, so we need to link with either
# OpenBLAS or vecLibFort (osx), this should be configured automatically ... we
# really need to move to CMake
#LDFLAGS+= -L$(SCHISM_BUILD_DIR)/lib -L. -lpthread -lm -lvecLibFort
LDFLAGS+= -L$(SCHISM_BUILD_DIR)/lib -L. -lpthread -lm -llapack -lblas -Wl,--allow-multiple-definition#-lscalapack #-lOpenBLAS
endif
endif

ifneq ($(wildcard $(SCHISM_BUILD_DIR)/lib/libparmetis.a),)
LIBS+= -lparmetis
endif

ifneq ($(wildcard $(SCHISM_BUILD_DIR)/lib/libmetis.a),)
LIBS+= -lmetis
endif

EXPAND_TARGETS= expand_schismlibs

ifneq ($(wildcard $(SCHISM_BUILD_DIR)/lib/libfabm.a),)
  $(info Include fabm libraries from $(SCHISM_BUILD_DIR)/lib/libfabm*.a)
  EXPAND_TARGETS+= expand_fabmlibs
  F90FLAGS += -DUSE_FABM
  LIBS+= -lfabm_schism -lfabm
endif

.SUFFIXES:
.PHONY: all lib test schism_nuopc_lib schism_esmf_lib install install-esmf install-nuopc pdaf
default: all

# User-callable make targets

all: lib test schism_nuopc_lib

lib: schism_esmf_lib schism_nuopc_lib

install: install-esmf install-nuopc

install-esmf:  schism_esmf_lib
	mkdir -p $(DESTDIR)
	cp $(SCHISM_BUILD_DIR)/lib/libhydro.a $(DESTDIR)
	cp $(SCHISM_BUILD_DIR)/lib/libcore.a $(DESTDIR)
	cp libschism_esmf.a $(DESTDIR)
	cp $(SCHISM_MODS) $(DESTDIR)

install-nuopc:  schism_nuopc_lib
	mkdir -p $(DESTDIR)
	cp $(SCHISM_BUILD_DIR)/lib/libhydro.a $(DESTDIR)
	if  test -f $(SCHISM_BUILD_DIR)/lib/libmetis.a; then cp $(SCHISM_BUILD_DIR)/lib/libmetis.a $(DESTDIR); fi
	if  test -f $(SCHISM_BUILD_DIR)/lib/libparmetis.a; then cp $(SCHISM_BUILD_DIR)/lib/libparmetis.a $(DESTDIR); fi
	if  test -f $(SCHISM_BUILD_DIR)/lib/libfabm_schism.a; then cp $(SCHISM_BUILD_DIR)/lib/libfabm_schism.a $(DESTDIR); fi
	cp $(SCHISM_BUILD_DIR)/lib/libcore.a $(DESTDIR)
	cp libschism_cap.a $(DESTDIR)
	cp libschism_cap.a $(SCHISM_BUILD_DIR)/lib
	#cp $(SCHISM_NUOPC_MODS) $(DESTDIR)
	cp $(SCHISM_NUOPC_MODS) $(SCHISM_BUILD_DIR)/include/
	sed 's#@@SCHISM_BUILD_DIR@@#'$(SCHISM_BUILD_DIR)'#g' ./src/schism/schism_nuopc_cap.mk.in > $(DESTDIR)/schism.mk
	#sed 's#@@SCHISM_BUILD_DIR@@#'$(SCHISM_BUILD_DIR)'#g' ./src/schism/schism_nuopc_cap.mk.in > $(SCHISM_BUILD_DIR)/include/schism.mk

##test: concurrent_esmf_test triple_schism multi_schism schism_pdaf
ifeq ($(USE_PDAF),ON)
test: pdaf 
pdaf: dep-pdaf schism_pdaf
endif

# Internal make targets for final linking
SCHISM_NUOPC_MODS=$(addprefix src/schism/,schism_nuopc_util.mod schism_nuopc_cap.mod)
SCHISM_NUOPC_OBJS=$(addprefix src/schism/,schism_nuopc_util.o schism_nuopc_cap.o)
SCHISM_ESMF_MODS=$(addprefix src/schism/,schism_esmf_cap.mod)
SCHISM_ESMF_OBJS=$(addprefix src/schism/,schism_esmf_cap.o)
SCHISM_MODS=$(addprefix src/schism/,schism_bmi.mod schism_esmf_util.mod)
SCHISM_OBJS=$(addprefix src/schism/,schism_bmi.o schism_esmf_util.o)
PDAF_OBJS=$(addprefix src/PDAF_bindings/,mod_parallel_pdaf.o mod_assimilation.o init_parallel_pdaf.o \
            init_pdaf.o init_pdaf_info.o finalize_pdaf.o init_ens_pdaf.o next_observation_pdaf.o \
            distribute_state_pdaf.o prepoststep_pdaf.o callback_obs_pdafomi.o \
            collect_state_pdaf.o init_dim_obs_all.o PDAFomi_obs_op_schism.o assimilate_pdaf.o \
            obs_A_pdafomi.o obs_Z_pdafomi.o obs_S_pdafomi.o obs_T_pdafomi.o obs_U_pdafomi.o obs_V_pdafomi.o \
            init_n_domains_pdaf.o init_dim_l_pdaf.o g2l_state_pdaf.o l2g_state_pdaf.o output_netcdf_pdaf.o)
#MODEL_OBJS=$(addprefix src/model/,atmosphere_cmi_esmf.o)

#concurrent_esmf_test: $(SCHISM_OBJS) $(MODEL_OBJS) concurrent_esmf_test.o
#	$(F90) $(CPPFLAGS) $^ -o $@ $(LDFLAGS) $(LIBS)

ifeq ($(USE_PDAF),ON)
schism_pdaf: install-esmf dep-pdaf $(PDAF_OBJS) $(SCHISM_OBJS) $(SCHISM_ESMF_OBJS) schism_pdaf.o
	$(F90) $(CPPFLAGS) $(PDAF_OBJS) $(SCHISM_OBJS) $(SCHISM_ESMF_OBJS) schism_pdaf.o -o $@ $(LDFLAGS)  -L./lib $(LIBS)
endif

schism_esmf_lib: dep-esmf dep-schism $(SCHISM_OBJS)  $(SCHISM_ESMF_OBJS) $(EXPAND_TARGETS)
	$(AR) crs libschism_esmf.a  $(SCHISM_OBJS) .objs/*/*.o

schism_nuopc_lib: dep-esmf dep-schism $(SCHISM_OBJS) $(SCHISM_NUOPC_OBJS) $(EXPAND_TARGETS)
	$(AR) crs libschism_cap.a  $(SCHISM_NUOPC_OBJS) $(SCHISM_OBJS) .objs/*/*.o

expand_schismlibs: dep-schism
	$(shell mkdir -p .objs/d; cd .objs/d; \
	$(AR) x $(SCHISM_BUILD_DIR)/lib/libcore.a ; \
		$(AR) x $(SCHISM_BUILD_DIR)/lib/libhydro.a ; \
		$(AR) x $(SCHISM_BUILD_DIR)/lib/libparmetis.a ; \
		$(AR) x $(SCHISM_BUILD_DIR)/lib/libmetis.a ; \
	)

# @todo the fabm lib symbols should be renamed, e.g., prefixed with schism_ to
# avoid duplicate symbols when coupling to other systems that also contain fabm
# A possible solution is provided by www.mossco.de/code in their
# scripts/rename_fabm_symbols.py
expand_fabmlibs: dep-fabm
	$(shell mkdir -p .objs/sf; cd .objs/sf; for L in $(SCHISM_BUILD_DIR)/lib/lib*fabm_schism.a ; do $(AR) x $$L; done)
	$(shell mkdir -p .objs/f; cd .objs/f; $(AR) x $(SCHISM_BUILD_DIR)/lib/libfabm.a )

$(PDAF_OBJS):
	make -C src/PDAF_bindings esmf

ifeq ($(USE_PDAF),ON)
$(SCHISM_ESMF_OBJS): $(PDAF_OBJS) $(SCHISM_OBJS)
else
$(SCHISM_ESMF_OBJS): $(SCHISM_OBJS)
endif
	make -C src/schism esmf

ifeq ($(USE_PDAF),ON)
$(SCHISM_NUOPC_OBJS): $(PDAF_OBJS) $(SCHISM_OBJS)
else
$(SCHISM_NUOPC_OBJS): $(SCHISM_OBJS)
endif
	make -C src/schism nuopc

ifeq ($(USE_PDAF),ON)
$(SCHISM_OBJS): $(PDAF_OBJS)
else
$(SCHISM_OBJS):
endif
	make -C src/schism common

#$(MODEL_OBJS):
#	make -C src/model esmf

clean:
	$(MAKE) -C src clean
	$(RM) *.o *.mod
	$(RM) $(SCHISM_OBJS) $(MODEL_OBJS) $(PDAF_OBJS)

distclean: clean
	$(RM) -rf .objs
	$(RM) -f fort.* flux.dat param.out.nml total.dat total_TR.dat mirror.out
	$(RM) -f concurrent_esmf_test triple_schism multi_schism schism_pdaf libschism_esmf.a
	$(RM) -f outputs/*nc
	$(RM) -f outputs/nonfatal*nc
	$(RM) -f PET*

# $(shell cd .objs/sf; nm fabm_schism.F90.o|grep 'fabm_mp\|fabm_types_mp' | awk '{printf $$2 " "; gsub("fabm_mp","s_fabm_mp",$$2); gsub("fabm_types_mp","s_fabm_types_mp",$$2); print $$2}'>replace.tsv; objcopy --redefine-syms=replace.tsv fabm_schism.F90.o)
# $(shell cd .objs/f; for O in *.o ; do rm -f replace.tsv; nm -f posix $$O |grep 'fabm_mp\|fabm_types_mp' | awk '{printf $$1 " "; gsub("fabm_mp","s_fabm_mp",$$1); gsub("fabm_types_mp","s_fabm_types_mp",$$1); print $$1}'>replace.tsv; printf "fabm._ s_fabm._\nfabm_types._ s_fabm_types._\n">> replace.tsv; objcopy --redefine-syms=replace.tsv $$O; done)
