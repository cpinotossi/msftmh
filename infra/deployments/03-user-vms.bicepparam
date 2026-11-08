using './03-user-vms.bicep'

param location = 'francecentral'
param userObjectIds = {
  mhuser1: '9e1b35c6-be5d-400d-894a-6710749bcc85'
  mhuser2: '154410a6-19f0-4e36-ad22-5fe8ae8c32c0'
  mhuser3: 'f8561663-9767-4db5-a0e0-806d181eb649'
  mhuser4: '00cbe872-d507-43f2-92c6-79c57ca88625'
  mhuser5: '3dc6caee-756a-4f5d-85a5-171f57e18cf1'
  mhuser6: '25703e62-9024-4419-886b-2ed4645888a6'
  mhuser7: '03064aac-ec01-4bd9-983c-061c305b52c9'
}
param adminSshPublicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCQAEVNojAJu3j2Lb+iB0Yrd2qY/sYpSP5cbNj2IoUnKvoOUg2wEOsSlrXkz2B3pZQy8Devx2XnEsd7VjvByhxRhC+/MvxEd+CIjXUsot2eoL+k1+929pPwJgzFL7UYXaVjVw8mZyzhXvQGFACYee2GaBsTE1E9149wwkcRRhCZRuwEJT3ZtCcVy6HmzrVnauEPaOj9tydRBvdXdWpclairs4nxlI77Ny6Ox7BwKZH6n67jQGTabzE0VZ2OZWGxDW6HdTGzfSlLbPpxo7cLIY+OjKJWiGgTKnElnrp7tx0oWBLkJ/ymKT9PYA46iAb2wj7Pp9szynJcVB2DmSjqssPyKSfaPxcZmSULNCGyX35qYQDVyDm3kldh7xcB4IX+i++y6mlbX3v7zqq6QdlwrsPgDJc6QVj9D5ABqBB4j+Tu/xtDhxk20mWO/HUAqdMurhyE1qI+5b9+uQB1GdLkok1unKHug251szHB2fePAFKk9evDHOyI1xL/KrFe5xLYnI29eOgSfTH6MxrKIs0M58oZSW1Ecf0dH5Yn1rQtV5iptb9VGgdkY7ThjIpPjwrPS61bSYhqLFC1YXTgwTVaDsMaobyCqQ0+qC5gf24NLQ78xi9TBHXwXmDNJAQ6if4JvrUIi9isDV8N2/PwsfB0LQwXn/PmD8+owEajoyxX/vJVaw== workshop-admin'
