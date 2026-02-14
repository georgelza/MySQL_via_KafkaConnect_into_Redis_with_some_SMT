#docker run --env-file ./conf/license.env --net host -v ./conf/config.json:/home/config.json -v ./conf/conn.json:/home/conn.json -v ./conf/tenants.json:/home/tenants.json shadowtraffic/shadowtraffic:1.11.13 --config /home/config.json 

#docker run --env-file ./conf/license.env --env-file ./conf/config.env --net host -v ./conf/config.json:/home/config.json -v ./conf/conn.json:/home/conn.json -v ./conf/tenants.json:/home/tenants.json shadowtraffic/shadowtraffic:1.11.13 --config /home/config.json --stdout --sample 20 --watch

#docker run --rm --env-file ./conf/license.env --env-file ./conf/config.env --net host -v ./conf/config.json:/home/config.json -v ./conf/conn.json:/home/conn.json -v ./conf/tenants.json:/home/tenants.json --name shadowtraffic2 shadowtraffic/shadowtraffic:1.11.13 --metrics-port 5010 --config /home/config.json --watch 

docker run --rm --env-file ./conf/free-trial-license.env --env-file ./conf/config.env --net host -v ./conf/config.json:/home/config.json -v ./conf/conn.json:/home/conn.json -v ./conf/tenants.json:/home/tenants.json --name shadowtraffic2 shadowtraffic/shadowtraffic:1.11.13 --metrics-port 5010 --config /home/config.json --watch 
