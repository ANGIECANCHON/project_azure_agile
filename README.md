# Overview

<TODO: complete this with an overview of your project>

## Project Plan
<TODO: Project Plan

* Trello Board -> https://trello.com/b/pyEgMvHt/udacity-project

## Instructions

<TODO:  
* Architectural Diagram 

![flow](./img/flowDiagram.png)

<TODO:  Instructions for running the Python project.  How could a user with no context run this project without asking you for any help.  Include screenshots with explicit steps to create that work. Be sure to at least include the following screenshots:

* Project running on Azure App Service

pipelane running ok

![pipelane](./img/full_azure_pipelane.png)

* Project cloned into Azure Cloud Shell

add ssh:

![pipelane](./img/ssh-console-gen.png)
![pipelane](./img/ssh-git.png)

clone repo

![pipelane](./img/clone_repo.png)

* Passing tests that are displayed after running the `make all` command from the `Makefile`

pass all the git pipelane

![pipelane](./img/pipelane_git.png)

* Output of a test run

![pipelane](./img/test_run.png)

* Successful deploy of the project in Azure Pipelines.  [Note the official documentation should be referred to and double checked as you setup CI/CD](https://docs.microsoft.com/en-us/azure/devops/pipelines/ecosystems/python-webapp?view=azure-devops).

* Running Azure App Service from Azure Pipelines automatic deployment

* Successful prediction from deployed flask app in Azure Cloud Shell.  [Use this file as a template for the deployed prediction](https://github.com/udacity/nd082-Azure-Cloud-DevOps-Starter-Code/blob/master/C2-AgileDevelopmentwithAzure/project/starter_files/flask-sklearn/make_predict_azure_app.sh).
The output should look similar to this:

```bash
udacity@Azure:~$ ./make_predict_azure_app.sh
Port: 443
{"prediction":[20.35373177134412]}
```

* Output of streamed log files from deployed application

> 

## Enhancements

<TODO: To improve the project I can update dependecies and add new predictions to get new data, and for the deployment I can use terraform to automated.>

## Demo 

The next URL is on canva and It will be reproduce the configuration to deploy the web app in azure

![pipelane](https://www.canva.com/design/DAFyeCdzl1c/Z5dRVPv1AgMwtTm_MzPOFQ/watch?utm_content=DAFyeCdzl1c&utm_campaign=designshare&utm_medium=link&utm_source=editor)
