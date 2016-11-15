#!/bin/bash

# source pmpi runtime environment
source /opt/ibm/platform_mpi/profile.pmpi

# run pmpi hello world example and record stdout
mpirun -lsf /home/lsfadmin/tools/hw > $(pwd)/output