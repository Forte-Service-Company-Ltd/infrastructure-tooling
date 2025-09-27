#!/bin/bash
export TERM=xterm-color
YELLOW='\033[33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
# Helper script for running the contract-size workflow

# Run the command and capture output
output=$(forge build --sizes src)
should_fail="false"

# Print header
printf "\n${NC}Contract Size Analysis:\n"
printf "  %-20s │ %s\n" "Contract Name" "Runtime Size"
printf "  %-20s │ %s\n" "────────────────────" "────────────"

# Process the output: remove commas, truncate to 69 chars, and loop through lines
while IFS= read -r line; do
    clean_line=$(echo "$line" | tr -d ',' | cut -c1-69)

    # Only process lines that are actual contract data (start with | and contain a contract name, but not header)
    if [[ ! "$line" =~ ^\|[[:space:]]+[[:alpha:]] ]] || [[ "$line" =~ "Contract.*Runtime Size" ]]; then
        continue
    fi

    # Extract the Runtime Size from the third column (delimited by |)
    num=$(echo "$line" | awk -F'|' '{gsub(/[^0-9]/, "", $3); print $3}')

    if [[ -n "$num" ]] && [[ "$num" =~ ^[0-9]+$ ]]; then
        # Extract contract name from second field (first field is empty due to leading |)
        contract=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2}')
        printf "  %-20s │ %6s bytes\n" "$contract" "$num"
        if (( num > 24576 )); then
            printf "${RED} FAIL ${NC} Contract found that exceeds the max size of 24Kb! ${RED} $contract ${NC} \n"
            printf "       Its size is: ${RED} $num ${NC} \n"
            should_fail="true"
        elif (( num > 21000 )); then
            printf "${YELLOW} WARNING ${NC} Contract found that is near the max size of 24Kb. ${YELLOW} $contract ${NC} \n"
            printf "          Its size is: ${YELLOW} $num ${NC} \n"
        fi
    fi
done <<< "$output"
if [ "$should_fail" = "true" ]; then
  printf "${RED} ERROR: Failed to pass all checks. See individual results for details.  \n"
  exit -1 # terminate and indicate error
fi
