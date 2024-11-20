#!/bin/bash
read -p "Number of iterations for the loop [25]: " num_iterations
num_iterations=${num_iterations:-25}
echo ${num_iterations}

read -p "Block size for dd command (1 MB blocks) [1M]: " BLOCK_SIZE
BLOCK_SIZE=${BLOCK_SIZE:-1M}
echo ${BLOCK_SIZE}

read -p "Number of blocks to write (10 MB total) [10]: " BLOCK_COUNT
BLOCK_COUNT=${BLOCK_COUNT:-10}
echo ${BLOCK_COUNT}

read -p "Should we delete or keep files? [yes]: " DELETE_FILE
DELETE_FILE=${DELETE_FILE:-yes}
echo ${DELETE_FILE}

for ((i=1; i<=num_iterations; i++))
do
    echo "=== Write to Disk Using dd ==="
    # Writing $BLOCK_SIZE MB of random data to the file
    dd if=/dev/urandom of="test_file_$i" bs=$BLOCK_SIZE count=$BLOCK_COUNT status=progress
    echo "Write complete."

    echo "=== Read from Disk Using dd ==="
    # Reading the file to /dev/null (simulating a read operation)
    dd if="test_file_$i" of=/dev/null bs=$BLOCK_SIZE status=progress
    echo "Read complete."

    if [[ $DELETE_FILE == yes ]] ; then
        rm -f test_file_$i
        echo "Cleanup complete."
    else
        echo "keep the test_file_$i"
        ls test_file_$i
    fi
done