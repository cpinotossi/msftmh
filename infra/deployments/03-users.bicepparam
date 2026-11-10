using './03-users.bicep'

param location = 'francecentral'
param workshopGroupId = '12ac252f-9249-47d5-b43c-5b29af74f9d5'
param organizerObjectId = '8c34642a-9444-4af7-b697-4953f3253126'
param userObjectIds = {
  mhuser1: '9e1b35c6-be5d-400d-894a-6710749bcc85'
  mhuser2: '154410a6-19f0-4e36-ad22-5fe8ae8c32c0'
  mhuser3: 'f8561663-9767-4db5-a0e0-806d181eb649'
  mhuser4: '00cbe872-d507-43f2-92c6-79c57ca88625'
  mhuser5: '3dc6caee-756a-4f5d-85a5-171f57e18cf1'
  mhuser6: '25703e62-9024-4419-886b-2ed4645888a6'
  mhuser7: '03064aac-ec01-4bd9-983c-061c305b52c9'
}
param firewallPrivateIp = '10.100.0.4'
