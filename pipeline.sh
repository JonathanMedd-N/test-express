export GITHUB_TOKEN=<redacted>
export GITHUB_OWNER=JonathanMedd-N
export GITHUB_REPO=test-express
export CODEQL_WORKFLOW_ID=codeql.yml
export BRANCH=test
export HEAD_SHA=e598b1e7ec323cc89bd50a9bf52a7ffcd46a7c5d

# Create workflow dispatch
  curl -L \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/workflows/$CODEQL_WORKFLOW_ID/dispatches \
  -d '{"ref": "'"$BRANCH"'"}'

# Sleep for 5 secs to allow it to appear
sleep 5

  # List workflow runs
WORKFLOW_RUNS=$(curl -L -s\
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/workflows/$CODEQL_WORKFLOW_ID/runs)


# Return most recent workflow run for a given sha
WORKFLOW_RUN_ID=$(echo $WORKFLOW_RUNS | jq -r '[.workflow_runs[] | select(.head_sha=="'"$HEAD_SHA"'" and .event=="workflow_dispatch")][0] | .id')

# Log workflow run number
WORKFLOW_RUN_NUMBER=$(echo $WORKFLOW_RUNS | jq -r '[.workflow_runs[] | select(.head_sha=="'"$HEAD_SHA"'" and .event=="workflow_dispatch")][0] | .run_number')
echo "Workflow run number is: $WORKFLOW_RUN_NUMBER"

#  Poll workflow run until complete
unset WORKFLOW_RUN_STATUS

until [ "$WORKFLOW_RUN_STATUS" == 'completed' ]
do 
    sleep 10
    WORKFLOW_RUN=$(curl -L -s\
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN"\
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/actions/runs/$WORKFLOW_RUN_ID)

    WORKFLOW_RUN_STATUS=$(echo $WORKFLOW_RUN | jq -r '.status')

    if [ "$WORKFLOW_RUN_STATUS" == 'completed' ]
    then
        echo "WORKFLOW_RUN_STATUS is: $WORKFLOW_RUN_STATUS, so exiting loop"
    else
        echo "WORKFLOW_RUN_STATUS is: $WORKFLOW_RUN_STATUS, so sleeping and checking again....."
    fi
done

# List code scanning analyses for a repository
SCANS=$(curl -L -s\
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN"\
  -H "X-GitHub-Api-Version: 2022-11-28" \
  https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/code-scanning/analyses)


#  Pick most recent scan for sha
SCAN=$(echo $SCANS | jq -r '[.[] | select(.commit_sha=="'"$HEAD_SHA"'")][0]')

RESULTS_COUNT=$(echo $SCAN | jq -r '.results_count')

if [ $RESULTS_COUNT == 0 ]
then
    echo "No security issues found with code in branch $BRANCH and commit $HEAD_SHA"
else
    echo "Security issues found with code in branch $BRANCH and commit $HEAD_SHA, retrieving full analysis"
    ANALYSIS_ID=$(echo $SCAN | jq -r '.id')

    # Get a code scanning analysis for a repository
    ANALYSIS=$(curl -L -s\
    -H "Accept: application/sarif+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN"\
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/code-scanning/analyses/$ANALYSIS_ID)

    echo "Full list of security issues:"
    echo $ANALYSIS | jq -r '.runs[0].results[] | {alertNumber: .properties."github/alertNumber", alertUrl: .properties."github/alertUrl", level: .level, location: .locations[0].physicalLocation.artifactLocation.uri, rule: .rule.id, message: .message.text}'
fi
