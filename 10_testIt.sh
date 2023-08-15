#!/bin/sh

OUTPUTFILE=testIt.out
# Not working export REPORT_GAS=true

npx hardhat test | tee $OUTPUTFILE
# npx hardhat coverage | tee $OUTPUTFILE
grep txFee $OUTPUTFILE | uniq
