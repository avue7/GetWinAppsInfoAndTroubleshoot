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
	$Process = Start-Process `
		-FilePath 'powershell' `
		-ArgumentList (
			#flatten to single array
			'-File', $MyInvocation.MyCommand.Source, $args `
			| %{ $_ }
		) `
		-Verb RunAs -PassThru
}

Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\Windows\PowerShell -Name ExecutionPolicy -Value ByPass


