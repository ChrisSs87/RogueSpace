param(
 [Parameter(Mandatory=$true)][string]$Worktree,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-fA-F]{40}$')][string]$ExpectedCommit,
 [Parameter(Mandatory=$true)][string]$TargetBranch,
 [string]$GitExecutable='C:/Users/chris/.cache/codex-runtimes/codex-primary-runtime/dependencies/native/git/cmd/git.exe',
 [switch]$Offline
)
# Read-only preparation. This script never executes push/commit/merge or writes
# config/credentials/files. Approval is external; an emitted command is not it.
$ErrorActionPreference='Stop'
if($TargetBranch -notmatch '^(feature|fix|chore|audit|develop|codex|claude|gemini|chatgpt)/[A-Za-z0-9][A-Za-z0-9._/-]*$'){
 throw 'Target must be a named work/development branch, never main/tag/refspec.'
}
$repo=(Resolve-Path -LiteralPath $Worktree).Path
$git=(Resolve-Path -LiteralPath $GitExecutable).Path
function Read-Git([string[]]$Arguments){
 $result=@(& $git -C $repo @Arguments)
 if($LASTEXITCODE -ne 0){throw 'Git check failed; stop, no retry or publication.'}
 return $result
}
$null=Read-Git @('check-ref-format','--branch',$TargetBranch)
$common=(Read-Git @('rev-parse','--path-format=absolute','--git-common-dir')) -join ''
$authorized='C:/Users/chris/OneDrive/Documentos/RogueSpace/official_repo/.git'
if($common.Replace('\','/').TrimEnd('/') -ine $authorized){throw 'Not the authorized RogueSpace repository.'}
$origin=(Read-Git @('config','--get','remote.origin.url')) -join ''
if($origin -cne 'https://github.com/ChrisSs87/RogueSpace.git'){throw 'Unexpected origin; no URL/credential values disclosed.'}
$fetchUrls=@(Read-Git @('remote','get-url','--all','origin'))
$pushUrls=@(Read-Git @('remote','get-url','--push','--all','origin'))
if($fetchUrls.Count -ne 1 -or $pushUrls.Count -ne 1 -or $fetchUrls[0] -cne $origin -or $pushUrls[0] -cne $origin){throw 'Resolved fetch/push URL override is not authorized.'}
$sourceBranch=(Read-Git @('symbolic-ref','--short','HEAD')) -join ''
if($sourceBranch -in @('main','master')){throw 'Do not publish from the stable branch.'}
$head=(Read-Git @('rev-parse','HEAD')) -join ''
if($head -ine $ExpectedCommit){throw 'HEAD does not match the approved commit.'}
if(@(Read-Git @('status','--porcelain','--untracked-files=all')).Count -gt 0){throw 'Worktree is dirty; recover/review first. Do not stage automatically.'}
$files=@(Read-Git @('ls-files'))
$suspect=@($files|Where-Object {$_ -match '(^|/)(\.git|\.godot|artifacts|builds|exports)(/|$)|(^|/)(\.env|credentials\.json|secrets\.json)$|\.(zip|apk|aab|exe|pdb|pem|pfx|key)$'})
if($suspect.Count){throw 'Tracked cache/build/archive/credential-like paths require review. No publication prepared.'}
$remoteState='NOT_CHECKED_OFFLINE'
if(-not $Offline){
 $oldPrompt=$env:GIT_TERMINAL_PROMPT
 $oldInteractive=$env:GCM_INTERACTIVE
 try{
  $env:GIT_TERMINAL_PROMPT='0';$env:GCM_INTERACTIVE='Never'
  $remote=@(Read-Git @('-c','credential.interactive=never','ls-remote','--heads','origin',('refs/heads/'+$TargetBranch)))
  if($remote.Count){throw 'Target already exists; never prepare an overwrite.'}
  $remoteState='ABSENT_AT_CHECK'
 }finally{
  $env:GIT_TERMINAL_PROMPT=$oldPrompt
  $env:GCM_INTERACTIVE=$oldInteractive
 }
}
function Quote-Literal([string]$s){return "'"+$s.Replace("'","''")+"'"}
$manual='& '+(Quote-Literal $git)+' -C '+(Quote-Literal $repo)+' push origin '+(Quote-Literal ($head+':refs/heads/'+$TargetBranch))
[pscustomobject]@{
 Repository=$repo;SourceBranch=$sourceBranch;Commit=$head;Target=$TargetBranch;
 RemoteStatus=$remoteState;Authorization='REQUIRES_EXPLICIT_APPROVAL';
 ManualCommand=$manual;WritesExecuted=$false
}
