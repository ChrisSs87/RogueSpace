param([Parameter(Mandatory=$true)][string]$CleanWorktree)
$ErrorActionPreference='Stop'
$helper=Join-Path $PSScriptRoot '../prepare-publication.ps1'
$git='C:/Users/chris/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/cmd/git.exe'
$sha=(& $git -C $CleanWorktree rev-parse HEAD)
if($LASTEXITCODE -ne 0){throw 'Need an existing clean authorized worktree'}
$result=& $helper -Worktree $CleanWorktree -ExpectedCommit $sha -TargetBranch 'develop/readonly-helper-test' -Offline
if($result.WritesExecuted -or $result.RemoteStatus -ne 'NOT_CHECKED_OFFLINE' -or $result.Commit -ne $sha -or $result.ManualCommand -match '--force|--delete'){throw 'Positive offline check failed'}
Write-Output 'PASS offline preparation; no publication'
foreach($branch in @('main','refs/tags/test','develop/test:refs/heads/main','develop/../main')){
 $rejected=$false
 try{& $helper -Worktree $CleanWorktree -ExpectedCommit $sha -TargetBranch $branch -Offline|Out-Null}catch{$rejected=$true}
 if(-not $rejected){throw 'Unsafe branch accepted'}
 Write-Output "PASS reject $branch"
}
$rejected=$false
try{& $helper -Worktree $CleanWorktree -ExpectedCommit ('0'*40) -TargetBranch 'develop/test' -Offline|Out-Null}catch{$rejected=$true}
if(-not $rejected){throw 'Unexpected SHA accepted'}
Write-Output 'PASS reject mismatched SHA'
# Dirty-worktree check is exercised separately against this uncommitted docs
# worktree; never make CleanWorktree dirty as part of a tooling test.
