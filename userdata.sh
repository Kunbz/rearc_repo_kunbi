#!bin/bash
sudo yum -y update && sudo yum -y install git
sudo amazon-linux-extras install docker -y
sudo service docker start
git clone https://github.com/rearc/quest.git 
cd quest
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
. ~/.nvm/nvm.sh
npm install
touch Dockerfile
cat > Dockerfile << EOF
FROM node:16
# Sets (and creates if it doesn't already exist) the working directory
WORKDIR /app
# Downloads a zip file of the node.js app from the master branch
RUN wget https://github.com/rearc/quest/archive/master.zip
# Unzips the node.js app
RUN unzip master.zip
# Moves the contents of the unzipped node.js package into it's parent directory
RUN mv quest-master/* ./
# Deletes the downloaded zip file and previously emptied app directory
RUN rm -rf master.zip quest-master
# Executues the install command
RUN npm install
# Specfifes port that will be exposed for given container
EXPOSE 3000
# Defines environment variables that are avaiable within the container
ENV SECRET_WORD TwelveFactor
# Executes the start command
CMD ["npm", "start"]
EOF
sudo docker build -t rearc-quest .
sudo docker run -d -p 80:3000 rearc-quest
sudo docker run -d -p 443:3000 rearc-quest
sudo docker run -d -p 3000:3000 rearc-quest
