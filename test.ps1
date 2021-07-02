param($Arg1)
# Set the argument to array variable
$args = @($Arg1)

$Global:StageAppResultReturn = ""

# BOILER PLATE CODE BLOCK:
# Self-elevated mode. Basically checks to see if current user
# is an admin. If not, then exit non-elevated and opens 
# new process in elevatd mode with program selected at "FilePath".
# If you have arguments passed to pass to this script from the 
# calling script, declare and set them to the array variable 
# "$args". 
if (!
	#current role
	(New-Object Security.Principal.WindowsPrincipal(
		[Security.Principal.WindowsIdentity]::GetCurrent()
	#is admin?
	)).IsInRole(


		[Security.Principal.WindowsBuiltInRole]::Administrator
	)
) {
	#elevate script and exit current non-elevated runtime
	$Proces = Start-Process `
		-FilePath 'powershell' `
		-ArgumentList (
			#flatten to single array
			'-File', $MyInvocation.MyCommand.Source, $args `
			| %{ $_ }
		) `
		-Verb RunAs -PassThru -Wait
    
    $Damn = Get-Variable -Name StageAppResultReturn
    
    Write-Host $Damn.value	

    write-host "blah $StageAppResultReturn"

    exit $Process.ExitCode
}

Set-Variable -Name StageAppResultReturn -Value "COME GET STARTED" -Option AllScope

$StageAppResultReturn = "$args[1] world! whohooooooooooo"
$args[1] += "What the fuck"

$StageAppResult = "SHIT"