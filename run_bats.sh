for file in scripts/tests/*.bats; do
    echo "Running $file"
    bats "$file"
done
