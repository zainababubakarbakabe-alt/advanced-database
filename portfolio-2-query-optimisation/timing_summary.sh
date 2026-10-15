#!/usr/bin/env bash
# Builds the before/after table from the medians recorded by run_benchmarks.sh
printf "%-34s %14s %14s %9s\n" query "before (ms)" "after (ms)" speed-up
for f in results/before_q*.txt; do
  q=$(basename "$f" .txt | sed 's/^before_//')
  b=$(awk '/median of 5/{print $(NF-1)}' "$f"); a=$(awk '/median of 5/{print $(NF-1)}' "results/after_$q.txt")
  printf "%-34s %14s %14s %8.1fx\n" "$q" "$b" "$a" "$(echo "$b / $a" | bc -l)"
done
