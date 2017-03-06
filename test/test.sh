#!/bin/bash
#
# Run all of the tests.
#
# If a failure occurs, find the failed messages and look at the
# associated line numbers.
#
# If, like me, you use different versions of python, you
# select them as follows:
#    ./test.sh 'python2.7 ../lock_files.py'
#    ./test.sh 'python3.6 ../lock_files.py'
#
# Note that file1.txt and file2.txt are copied to intermediate
# files throughout the tests. This is so that test data is not
# destroyed if there is a problem.

# ================================================================
# Functions
# ================================================================
# Print an info message with context (caller line number)
function info() {
    local Msg="$*"
    echo -e "INFO:${BASH_LINENO[0]}: $Msg"
}

function Fail() {
    (( Failed++ ))
    (( Total++ ))
    local Tid="$1"
    local Memo="$2"
    printf "test:%03d:%s:failed %s\n" $Total "$Tid" "$Memo"
    Done
}

function Pass() {
    (( Passed++ ))
    (( Total++ ))
    local Tid="$1"
    local Memo="$2"
    printf "test:%03d:%03d:passed %s\n" $Total "$Tid" "$Memo"
}

function Done() {
    echo
    printf "test:total:passed  %3d\n" $Passed
    printf "test:total:failed  %3d\n" $Failed
    printf "test:total:summary %3d\n" $Total
    
    echo
    if (( Failed )) ; then
        echo "FAILED"
    else
        echo "PASSED"
    fi
    exit $Failed
}

# ================================================================
# Main
# ================================================================
Passed=0
Failed=0
Total=0
Prog=${1:-"../lock_files.py"}
info "Prog=$Prog"
rm -f test*.txt*

# Test simple lock.
cp file1.txt test.txt
tid=${LINENO}
$Prog -P secret --lock test.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

# Make sure that the locked file exists.
tid=${LINENO}
if [ -e 'test.txt.locked' ] ; then
    Pass $tid "lock-exists"
else
    Fail $tid "lock-exists"
fi

# Test simple unlock.
tid=${LINENO}
$Prog -P secret --unlock test.txt.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

# Make sure that the unlocked file exists.
tid=${LINENO}
if [ -e 'test.txt' ] ; then
    Pass $tid "unlock-exists"
else
    Fail $tid "unlock-exists"
fi

# Make sure that the contents did not change.
tid=${LINENO}
diff file1.txt test.txt
if (( $? == 0 )) ; then
    Pass $tid "nodiff"
else
    Fail $tid "nodiff"
fi
    
# Now try globbing and locking.
cp file1.txt test1.txt
cp file2.txt test2.txt
tid=${LINENO}
$Prog -P secret --lock test[12].txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

# Make sure that the locked file exists.
tid=${LINENO}
if [ -e 'test1.txt.locked' ] ; then
    Pass $tid "test1-lock-exists"
else
    Fail $tid "test1-lock-exists"
fi

tid=${LINENO}
if [ -e 'test2.txt.locked' ] ; then
    Pass $tid "test2-lock-exists"
else
    Fail $tid "test2-lock-exists"
fi

# Now try globbing and unlocking.
tid=${LINENO}
$Prog -P secret --unlock test[12]*.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

# Make sure that the unlocked file exists.
tid=${LINENO}
if [ -e 'test1.txt' ] ; then
    Pass $tid "test1-unlock-exists"
else
    Fail $tid "test1-unlock-exists"
fi

tid=${LINENO}
if [ -e 'test2.txt' ] ; then
    Pass $tid "test2-unlock-exists"
else
    Fail $tid "test2-unlock-exists"
fi

tid=${LINENO}
diff file1.txt test1.txt
if (( $? == 0 )) ; then
    Pass $tid "nodiff1"
else
    Fail $tid "nodiff1"
fi

tid=${LINENO}
diff file2.txt test2.txt
if (( $? == 0 )) ; then
    Pass $tid "nodiff2"
else
    Fail $tid "nodiff2"
fi

# Try a different suffix.
cp file1.txt test1.txt
tid=${LINENO}
$Prog -P secret -s '.FOO' --lock test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

# Make sure that the locked file exists.
tid=${LINENO}
if [ -e 'test1.txt.FOO' ] ; then
    Pass $tid "lock-exists"
else
    Fail $tid "lock-exists"
fi

# Test simple unlock.
tid=${LINENO}
$Prog -P secret -s '.FOO' --unlock test1.txt.FOO
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

# Make sure that the unlocked file exists.
tid=${LINENO}
if [ -e 'test1.txt' ] ; then
    Pass $tid "unlock-exists"
else
    Fail $tid "unlock-exists"
fi

# Test simple lock using short forms.
cp file1.txt test1.txt
tid=${LINENO}
$Prog -P secret -l test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

# Make sure that the locked file exists.
tid=${LINENO}
if [ -e 'test1.txt.locked' ] ; then
    Pass $tid "lock-exists"
else
    Fail $tid "lock-exists"
fi

# Test simple unlock.
tid=${LINENO}
$Prog -P secret -u test1.txt.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

# Make sure that the unlocked file exists.
tid=${LINENO}
if [ -e 'test1.txt' ] ; then
    Pass $tid "unlock-exists"
else
    Fail $tid "unlock-exists"
fi

# Test simple lock using default and forms.
cp file1.txt test1.txt
tid=${LINENO}
$Prog -P secret test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

# Make sure that the locked file exists.
tid=${LINENO}
if [ -e 'test1.txt.locked' ] ; then
    Pass $tid "lock-exists"
else
    Fail $tid "lock-exists"
fi

# Test simple unlock.
tid=${LINENO}
$Prog -P secret -u test1.txt.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

# Make sure that the unlocked file exists.
tid=${LINENO}
if [ -e 'test1.txt' ] ; then
    Pass $tid "unlock-exists"
else
    Fail $tid "unlock-exists"
fi

# Test directories - recurse.
# setup
rm -rf tmp
mkdir tmp
cp file1.txt tmp/
mkdir tmp/tmp
cp file1.txt tmp/tmp
cp file2.txt tmp/tmp
tree tmp

tid=${LINENO}
if [ -e "tmp/tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/tmp/file2.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
$Prog -P secret -v -v tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ -e "tmp/tmp/file1.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/tmp/file2.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/file1.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tree tmp

tid=${LINENO}
$Prog -P secret -v -v --unlock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ -e "tmp/tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/tmp/file2.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tree tmp
rm -rf tmp

# Test directories - no recurse.
# setup
rm -rf tmp
mkdir tmp
cp file1.txt tmp/
mkdir tmp/tmp
cp file1.txt tmp/tmp
tree tmp

tid=${LINENO}
if [ -e "tmp/tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
$Prog -P secret -v -v -n tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ ! -e "tmp/tmp/file1.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/file1.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tree tmp

tid=${LINENO}
$Prog -P secret -v -v --unlock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ -e "tmp/tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "tmp/file1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tree tmp
rm -rf tmp

# test continue --cont, -c
cp file1.txt test1.txt
cp file2.txt test2.txt
tid=${LINENO}
$Prog -P secret -v -v --lock -c test1.txt testXXX.txt test2.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ -e "test1.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "test2.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
$Prog -P secret -v -v --unlock -c test1.txt.locked testXXX.txt.locked test2.txt.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

tid=${LINENO}
if [ -e "test1.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
if [ -e "test2.txt" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

# test locked extension.
cp file1.txt test1.txt.locked
tid=${LINENO}
$Prog -P secret -v -v --lock test1.txt.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ -e "test1.txt.locked.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

tid=${LINENO}
$Prog -P secret -v -v --unlock -c test1.txt.locked.locked
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

tid=${LINENO}
if [ -e "test1.txt.locked" ] ; then
    Pass $tid "setup"
else
    Fail $tid "setup"
fi

rm -f test1.txt.locked

# Test overwrite functionality.
# -s '' -o
cp file1.txt test1.txt
wc test1.txt
sum test1.txt
tid=${LINENO}
$Prog -P secret -v -v --lock -o -s '' test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ ! -e "test1.txt.lock" ] ; then
    Pass $tid "lock-not-found"
else
    Fail $tid "lock-not-found"
fi

tid=${LINENO}
if [ -e "test1.txt" ] ; then
    Pass $tid "file-found"
else
    Fail $tid "file-found"
fi

wc test1.txt
sum test1.txt

tid=${LINENO}
$Prog -P secret -v -v --unlock -o -s '' test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

tid=${LINENO}
if [ -e "test1.txt" ] ; then
    Pass $tid "file-found"
else
    Fail $tid "file-found"
fi

wc test1.txt
sum test1.txt

# Test inplace mode.
cp file1.txt test1.txt
wc test1.txt
sum test1.txt
tid=${LINENO}
$Prog -P secret -v -v --lock -i test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "lock-run"
else
    Fail $tid "lock-run"
fi

tid=${LINENO}
if [ ! -e "test1.txt.lock" ] ; then
    Pass $tid "lock-not-found"
else
    Fail $tid "lock-not-found"
fi

tid=${LINENO}
if [ -e "test1.txt" ] ; then
    Pass $tid "file-found"
else
    Fail $tid "file-found"
fi

wc test1.txt
sum test1.txt

tid=${LINENO}
$Prog -P secret -v -v --unlock -i test1.txt
st=$?
if (( $st == 0 )) ; then
    Pass $tid "unlock-run"
else
    Fail $tid "unlock-run"
fi

tid=${LINENO}
if [ -e "test1.txt" ] ; then
    Pass $tid "file-found"
else
    Fail $tid "file-found"
fi

wc test1.txt
sum test1.txt

# Test different lengths to verify padding.
for(( i=1; i<=32; i++ )) ; do
    str=""
    for(( j=1; j<=i; j++ )) ; do
        (( k = j % 10 ))
        str+="$k"
    done
    echo "$str" >test1.txt
    tid=${LINENO}
    $Prog -P secret -v -v --lock -i test1.txt
    st=$?
    if (( $st == 0 )) ; then
        Pass $tid "lock-run-$i"
    else
        Fail $tid "lock-run-$i"
    fi

    tid=${LINENO}
    $Prog -P secret -v -v --unlock -i test1.txt
    st=$?
    if (( $st == 0 )) ; then
        Pass $tid "unlock-run-$i"
    else
        Fail $tid "unlock-run-$i"
    fi
done

# Test different processing of 100 files to verify threading.
info 'setup for jobs test'
rm -rf tmp
mkdir tmp
for(( i=1; i<=200; i++ )) ; do
    fn=$(echo "$i" | awk '{printf("tmp/test%03d.txt", $1)}')
    cp file1.txt "$fn"
done
info 'setup done'

tid=${LINENO}
if [ -e "tmp/test001.txt" ] ; then
    Pass $tid "job-test001-check"
else
    Fail $tid "job-test001-check"
fi

tid=${LINENO}
if [ -e "tmp/test200.txt" ] ; then
    Pass $tid "job-test200-check"
else
    Fail $tid "job-test200-check"
fi

tid=${LINENO}
$Prog -P secret -v -v --lock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "job-lock"
else
    Fail $tid "job-lock"
fi

tid=${LINENO}
$Prog -P secret -v -v --unlock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "job-unlock"
else
    Fail $tid "job-unlock"
fi

# performance analysis (10 threads)
# Use big files.
info 'setup for jobs performance analysis'
rm -rf tmp
mkdir tmp
for(( i=1; i<=200; i++ )) ; do
    fn=$(echo "$i" | awk '{printf("tmp/test%03d.txt", $1)}')
    if (( i == 1 )) ; then
        # Create a big file for the first one.
        for(( j=1; j<=2000; j++)) ; do
            cat file1.txt >> "$fn"
        done
    else
        cp tmp/test001.txt $fn
    fi
done
info 'setup done'

tid=${LINENO}
if [ -e "tmp/test001.txt" ] ; then
    Pass $tid "job-test001-check"
else
    Fail $tid "job-test001-check"
fi

tid=${LINENO}
if [ -e "tmp/test100.txt" ] ; then
    Pass $tid "job-test100-check"
else
    Fail $tid "job-test100-check"
fi

tid=${LINENO}
time $Prog -P secret -v -j 10 --lock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "job-th10-lock"
else
    Fail $tid "job-th10-lock"
fi

tid=${LINENO}
time $Prog -P secret -v -j 10 --unlock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "job-th10-unlock"
else
    Fail $tid "job-th10-unlock"
fi

# performance analysis (1 thread)
tid=${LINENO}
time $Prog -P secret -v -j 1 --lock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "job-th1-lock"
else
    Fail $tid "job-th1-lock"
fi

tid=${LINENO}
time $Prog -P secret -v -j 1 --unlock tmp
st=$?
if (( $st == 0 )) ; then
    Pass $tid "job-th1-unlock"
else
    Fail $tid "job-th1-unlock"
fi

rm -rf test*.txt* tmp *~

Done
