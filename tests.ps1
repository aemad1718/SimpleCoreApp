$testProjects = @("D:\Learning\SimpleCoreApp\SimpleCoreApp.Tests")                                  # Array of test projects containing the xUnit tests you want to run, relative to the workspace directory
$filterRootNamespace = "SimpleCoreApp"                                                         # If you only want to get coverage for a specific root namespace, eg. "MyCompany.*" Leave empty otherwise
$reportGeneratorHistoryPath = "C:\BuildCoverageReportHistories\SimpleCoreApp.WebDocumentation" # Path where the history of the code coverage Html reports are stored - Must be outside the workspace so it does get. Leave empty if no history is wanted
# Modify the values below here if you need to - Standards should be fine
$dotnetPath = "C:\Program Files\dotnet\dotnet.exe"
$jenkinsWorkspace = $ENV:WORKSPACE # Use $ENV:WORKSPACE in Jenkins
$codeCoverageHtmlReportDirectory = "CodeCoverageHtmlReport"
$xUnitResultName = "xUnitResults.testresults"
$openCoverResultPath = Join-Path -Path $jenkinsWorkspace -ChildPath "OpenCoverCoverageReport.coverage"
$coberturaResultPath = Join-Path -Path $jenkinsWorkspace -ChildPath "CoberturaCoverageReport.coberturacoverage"
# Get the most recent ReportGenerator NuGet package from the dotnet nuget packages
$nugetReportGeneratorPackage = Join-Path -Path $env:USERPROFILE -ChildPath "\.nuget\packages\ReportGenerator"
$latestReportGenerator = Join-Path -Path ((Get-ChildItem -Path $nugetReportGeneratorPackage | Sort-Object Fullname -Descending)[0].FullName) -ChildPath "tools\ReportGenerator.exe"
# Get the most recent OpenCover NuGet package from the dotnet nuget packages
$nugetOpenCoverPackage = Join-Path -Path $env:USERPROFILE -ChildPath "\.nuget\packages\OpenCover"
$latestOpenCover = Join-Path -Path ((Get-ChildItem -Path $nugetOpenCoverPackage | Sort-Object Fullname -Descending)[0].FullName) -ChildPath "tools\OpenCover.Console.exe"
# Get the most recent OpenCoverToCoberturaConverter from the dotnet nuget packages
$nugetCoberturaConverterPackage = Join-Path -Path $env:USERPROFILE -ChildPath "\.nuget\packages\OpenCoverToCoberturaConverter"
$latestCoberturaConverter = Join-Path -Path (Get-ChildItem -Path $nugetCoberturaConverterPackage | Sort-Object Fullname -Descending)[0].FullName -ChildPath "tools\OpenCoverToCoberturaConverter.exe"
# Run unit tests with OpenCover attached for each test project
ForEach ($testProject in $testProjects){
    $testProjectPath = Join-Path -Path $jenkinsWorkspace -ChildPath $testProject
    # Create a unique output file name for the xUnit result
    $xUnitOutputCommand = "-xml \""" + (Join-Path -Path $jenkinsWorkspace -ChildPath ([Guid]::NewGuid().ToString() + "_" + $xUnitResultName)) + "\"""
    # Construct OpenCover arguments
    $openCoverArguments = New-Object System.Collections.ArrayList
    [void]$openCoverArguments.Add("-register:user")
    [void]$openCoverArguments.Add("-target:""" + $dotnetPath + """")
    [void]$openCoverArguments.Add("-targetargs:"" test " + "\""" +$testProjectPath + "\project.json\"" " + $xUnitOutputCommand + """") # dnx arguments
    [void]$openCoverArguments.Add("-output:""" + $openCoverResultPath + """") # OpenCover result output
    [void]$openCoverArguments.Add("-returntargetcode") # Force OpenCover to return an errorenous exit code if the xUnit runner returns one
    [void]$openCoverArguments.Add("-mergeoutput") # Needed if there are multiple test projects
    [void]$openCoverArguments.Add("-oldstyle") # Necessary until https://github.com/OpenCover/opencover/issues/595 is resolved
    if(!([System.String]::IsNullOrWhiteSpace($filterRootNamespace))) {
        [void]$openCoverArguments.Add("-filter:""+[" + $filterRootNamespace + "*]*""") # Check only defined namespaces if specified
    }
    # Run OpenCover with the dotnet text command
    "Running OpenCover tests with the dotnet test command"
    $openCoverProcess = Start-Process -FilePath $latestOpenCover -ArgumentList $openCoverArguments -Wait -PassThru -NoNewWindow
}
# Converting coverage reports to Cobertura format
$coberturaConverterArguments = New-Object System.Collections.ArrayList
[void]$coberturaConverterArguments.Add("-input:""" + $openCoverResultPath + """")
[void]$coberturaConverterArguments.Add("-output:""" + $coberturaResultPath + """")
[void]$coberturaConverterArguments.Add("-sources:""" + $jenkinsWorkspace + """")
$coberturaConverterProcess = Start-Process -FilePath $latestCoberturaConverter -ArgumentList $coberturaConverterArguments -Wait -PassThru -NoNewWindow
if ($coberturaConverterProcess.ExitCode -ne 0) {
    "Exiting due to CoberturaToOpenCoverConverter process having returned an error, exit code: " + $coberturaConverterProcess.ExitCode
    exit $coberturaConverterProcess.ExitCode
} else {
    "Finished running CoberturaToOpenCoverConverter"
}
"Creating the Html report for code coverage results"
# Creating the path for the Html code coverage reports
$codeCoverageHtmlReportPath = Join-Path -Path $jenkinsWorkspace -ChildPath $codeCoverageHtmlReportDirectory
if (-Not (Test-Path -Path $codeCoverageHtmlReportPath -PathType Container)) {
    New-Item -ItemType directory -Path $codeCoverageHtmlReportPath | Out-Null
}
# Create arguments to be passed to the ReportGenerator executable
$reportGeneratorArguments = New-Object System.Collections.ArrayList
[void]$reportGeneratorArguments.Add("-reports:""" + $openCoverResultPath + """")
[void]$reportGeneratorArguments.Add("-targetdir:""" + $codeCoverageHtmlReportPath + """")
if(!([System.String]::IsNullOrWhiteSpace($reportGeneratorHistoryPath))) {
    "Using history for ReportGenerator with directory: " + $reportGeneratorHistoryPath
    [void]$reportGeneratorArguments.Add("-historydir:""" + $reportGeneratorHistoryPath + """") # Check only defined namespaces if specified
} else {
    "Not using history for ReportGenerator"
}
# Run ReportGenerator
$reportGeneratorProcess = Start-Process -FilePath $latestReportGenerator -ArgumentList $reportGeneratorArguments -Wait -PassThru -NoNewWindow
if ($reportGeneratorProcess.ExitCode -ne 0) {
    "Exiting due to ReportGenerator process having returned an error, exit code: " + $reportGeneratorProcess.ExitCode
    exit $reportGeneratorProcess.ExitCode
} else {
    "Finished running ReportGenerator"
}
"Finished running unit tests and code coverage"