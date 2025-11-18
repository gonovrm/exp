from socket import *
# TO DO: modify the serverName and serverPort variables according to the 
# server-side IP and port configured within the laboratory network scenario 
serverName = ""
serverPort = 
clientSocket = socket(AF_INET, SOCK_DGRAM)
message = input("Enter a text here: ")
clientSocket.sendto(message.encode(),(serverName, serverPort))
modifiedMessage, serverAddress = clientSocket.recvfrom(2048)
print("From UDP Server:", modifiedMessage.decode('utf_8'))
clientSocket.close()
