@ECHO OFF

if "%~1"=="" (
    echo Usage: %0% ^<deployment^>
    exit /b 1
)

set DEPLOYMENT_ENVIRONMENT=%1

echo DEPLOYMENT_ENVIRONMENT = %DEPLOYMENT_ENVIRONMENT%

set VAR_FILENAME=deploy_config\vars\%DEPLOYMENT_ENVIRONMENT%.yml

echo VAR_FILENAME = %VAR_FILENAME%

if not exist %VAR_FILENAME% (
    echo %VAR_FILENAME% does not exist, please copy deploy_config\vars\example.yml to %VAR_FILENAME% and fill in your secrets.
    exit /b 1
)

git rev-parse HEAD > commit_hash.txt
set /p CLOUDREACTOR_TASK_VERSION_SIGNATURE= < commit_hash.txt
del commit_hash.txt

echo CLOUDREACTOR_TASK_VERSION_SIGNATURE = %CLOUDREACTOR_TASK_VERSION_SIGNATURE%

type nul >> deploy.env
type nul >> "deploy.%DEPLOYMENT_ENVIRONMENT%.env"


docker run --rm -e DEPLOYMENT_ENVIRONMENT ^
 -e CLOUDREACTOR_TASK_VERSION_SIGNATURE --env-file deploy.env ^
 --env-file "deploy.%DEPLOYMENT_ENVIRONMENT%.env" ^
 -v /var/run/docker.sock:/var/run/docker.sock ^
 -v %dp0\sample_docker_context:/work/docker_context ^
 -v %dp0\deploy_config:/work/deploy_config ^
 cloudreactor/aws-ecs-cloudreactor-deployer "./deploy.sh" %*
