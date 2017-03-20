***************************************** The Utility Scripts in this folder **********************************************
 
GenerateContainers:
    - a utility for generating Predix Machine containers without having to install the SDK into an Eclipse environment.
    Given the right arguments, GenerateContainers script will internally invoke DockerizeContainer (described below) script 
    and produce a docker image with the generated Predix Machine installed in one step. 
    This tool can also be used for a continuous integration model.

    Requirements: Eclipse and Maven, and Docker if using the Docker option.
        Download an Eclipse for generation. This should stay in the zip or tar.gz form. 
        i.e. https://eclipse.org/downloads/ and select the "Eclipse IDE for Java Developers" 
        Whatever Eclipse is selected must have the PDE runtime plugins. This would include the JEE version.

    Run the script with -h for detailed usage instructions.
        Unix/Linux:
           sh GenerateContainers.sh -h
        Windows
           GenerateContainers.bat -h


DockerizeContainer:
    - a utility for building a docker image with Predix Machine installed.
    This tool can also be used for a continuous integration model.
    
    Examples of valid architectures for the purpose of these instructions are - x86_64 and armhf.
    Requirements:
        - a Predix Machine container, such as one produced by the GenerateContainers script above, or with Eclipse.
        - docker engine installed on the host machine
        - the appropriate base docker image 
          e.g. dtr-alpha.gear.ge.com/predixmachine/openjdk-jre-<architecture>-<version>, installed into Docker's cache.
          If you do not already have the image loaded into your local Docker cache already, you can download the appropriate tarball for the image
          from artifactory (e.g. predixmachine-openjdk-jre-x86_64-1.0.0.tar.gz) and load it into Docker using -
          docker load -i predixmachine-openjdk-jre-x86_64-1.0.0.tar.gz
        
    Run the script with -h for detailed usage instructions.
        Unix/Linux:
            sh DockerizeContainer.sh -h
        Windows:
            DockerizeContainer.bat -h
            
            
******************* How To Prepare A Device To Run The Containerized Predix Machine  ***********************************

Download links for the required files are available at the documentation site on https://www.predix.io.


1. Obtain a supported device. The following platforms are provided in the download links:
    - a Virtualbox Ubuntu 14.04 VM with Docker installed. (User: predix, Password: predix2machine)
        First install Oracle VM Virtualbox Manager software, then load the appliance. File menu -> Import Appliance.
    - a Raspberry Pi 3 image with Docker and Resin Supervisor installed. (User: root, no password)
        Download the disk image, untar, and burn it to a micro SD card for the Raspberry Pi.

2. Start the device and copy the architecture-appropriate variants of the following files to the device:
    - Resin Supervisor:
        Ubuntu:
         - Resin Supervisor is available as a .deb package for Ubuntu 14.04 platform - predixmachine-resin-supervisor-<version>.deb. 
        Raspberry Pi:
         - the Resin Supervisor comes installed in the disk image.
         NOTE: scp/ssh on the Raspberry Pi are configured to use port 22222. 
    
    - PredixMachine bootstrap docker image - predixmachine-bootstrap-alpine-<architecture>-<version>.tar.gz.
        
    - Predix Machine agent docker image - predixmachine-agent-<architecture>-<version>.tar.gz.  
        Users who have customized Predix Machine may replace this with their own containerized version, prepared with the 
        GenerateContainers and DockerizeContainer scripts.
    
    - Mosquitto Messaging Broker docker image - predixmachine-mosquitto-<architecture>-<version>.tar.gz
    
    - Docker images for any other applications - such as ones created with edge SDK - provided as docker images archived as tar.gz.
    
3. Install the  Resin Supervisor:
    Ubuntu: 
        sudo dpkg -i predixmachine-resin-supervisor-<version>.deb
        NOTE: The Resin Supervisor installation adds a system daemon service, but does not start it. 
        If the host machine is rebooted at this time, the service would start and the opportunity 
        to perform first run configuration would be lost. If this happens, follow these steps -
            sudo service resin-supervisor stop
            sudo rm -r /etc/resin-supervisor/resin-data/
    Raspberry Pi:
        The service is already running when the device starts. Stop the service and reset the environment to new state.
            systemctl stop resin-supervisor
            rm -r /mnt/data/resin-data/resin-supervisor
        
4. Configure Resin Supervisor:
    a. Edit (create if none exists) config.json in the /etc/resin-supervisor ( /mnt/conf for Raspberry Pi) directory. 
    It should have the following content:
    
    {
        "supervisorOfflineMode":true, 
        "listenPort":"48484"
    }

    b. Edit (create if none exists) /etc/resin-supervisor/apps.json (/mnt/data/apps.json for Pi). It should have the 
    following content:
    NOTE: For Pi, a folder named apps.json may already exist in /mnt/data - remove it and replace with the file:
        rm -rf /mnt/data/apps.json

    [
     {
       "appId":1,
       "ImageId":"bootstrap:latest",
       "commit":"none",
       "env": {
       }
     }
    ]

    [Optional] If certificate enrollment to EdgeManager will be used for this device, the necessary information should
    be entered between the braces of the 'env' entry in apps.json. Specific values should replace the place-holders in 
    angle brackets in the template below. 
    
        "SHARED_SECRET":"<secret>",
        "CAF_SYSTEM_UDI":"<serial number>",
        "EDGE_MANAGER_URL":"<https://somewhere.edgemanager.ge.com>"
            
5. Load the bootstrap image into Docker's cache.
    docker load -i predixmachine-bootstrap-alpine-<architecture>-<version>.tar.gz

6. Start the Resin Supervisor service:
    Ubuntu:
        sudo service resin-supervisor start
    Raspberry Pi:
        systemctl start resin-supervisor
        
7. Copy the docker image archives for Predix Machine, Mosquitto, and any other custom applications to the directory 
monitored by bootstrap. Bootstrap will load the images and start containers. The process may take a little while,
including time for the polling interval, time to load images and start containers.  
    Ubuntu: 
        sudo cp predixmachine-agent-x86_64-<version>.tar.gz predixmachine-mosquitto-x86_64-<version>.tar.gz /etc/resin-supervisor/resin-data/1
    Pi 3:
        cp predixmachine-agent-armhf-<version>.tar.gz predixmachine-mosquitto-armhf-<version>.tar.gz /resin-data/1
8. Verify that the images were loaded and the containers started -
   docker images
   docker ps
   
******************* Debugging on the VM  ***********************************

To look at machine configuration or data files, you can use sudo to view the resin-data folder or change to root user:
        sudo -Es
    
1. To view logs from the VM, you can tail the resin-data folder. Normally predix machine is added as container 1. For example:
        tail -f /etc/resin-supervisor/resin-data/containers/1/logs/machine/machine.log
        
2. To view console output from any container including predix machine
    Determine what the name of the container is by doing "docker ps". For example to view the machine console:
        docker logs -f Predix_Machine

3. You can create a bash console for any container to move around and change things. i.e.
        docker exec -ti Predix_Machine bash
        
4. To update a bundle in the docker container, you can rebuild the docker container with the generate container script and drop the docker container into the bootloader watch folder:
        cp newdocker.tar.gz /etc/resin-supervisor/resin-data/1
   Alternatives: 
        use the webconsole (agent_debug) container that has the bundle menu for updating bundles.
        use docker copy: docker cp mybundle.jar Predix_Machine:/PredixMachine/machine/bundles
        Don't forget to restart the container after copying the bundle: docker restart Predix_Machine
   
    
        