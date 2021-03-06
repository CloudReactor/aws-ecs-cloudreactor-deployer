@ECHO OFF
ECHO Copying deploy-requirements.txt back to host ...
set IMAGE_NAME=aws-ecs-cloudreactor-deployer
set TEMP_CONTAINER_NAME="%IMAGE_NAME%-temp"

docker create --name %TEMP_CONTAINER_NAME% %IMAGE_NAME%
docker cp %TEMP_CONTAINER_NAME%:/tmp/deploy-requirements.txt deploy-requirements.txt
docker rm %TEMP_CONTAINER_NAME%

ECHO Done copying deploy-requirements.txt back to host.
