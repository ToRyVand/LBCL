#!/bin/bash
#Transacciones En Bitcoin Core 25.0 -Regtest + .
#By: ToRy "☯The Purpple⚡ 🥷🏻ＮＩＮＪΛ🥷"

echo "Starting Bitcoin..."
bitcoind -daemon

#creando dos wallets
bitcoin-cli -named createwallet wallet_name="Miner" descriptors=true
bitcoin-cli -named createwallet wallet_name="Trader" descriptors=true

#Obtenemos el balance y 150 minando 103 bloques
address_mining=$(bitcoin-cli -rpcwallet=Miner getnewaddress "Mineria")
bitcoin-cli generatetoaddress 103 "$address_mining"


final_balance=$(bitcoin-cli -rpcwallet=Miner getbalance)
echo "Saldo final de la billetera Miner: $final_balance"

#Direccion de Trader para recibir + Direccion de Miner Cambio
address_traderreceiver=$(bitcoin-cli -rpcwallet=Trader getnewaddress "Recibido")
address_minergiveback=$(bitcoin-cli -rpcwallet=Miner getnewaddress "Cambio")

#Transaccion en crudo + jq 
utxo_txid_0=$(bitcoin-cli -rpcwallet=Miner listunspent | jq -r '.[0] | .txid')
utxo_vout_0=$(bitcoin-cli -rpcwallet=Miner listunspent | jq -r '.[0] | .vout')
utxo_txid_1=$(bitcoin-cli -rpcwallet=Miner listunspent | jq -r '.[1] | .txid')
utxo_vout_1=$(bitcoin-cli -rpcwallet=Miner listunspent | jq -r '.[1] | .vout')

#Armando la transaccion + 2 salidas + 1 entrada
txParent=$(bitcoin-cli -named createrawtransaction inputs='''[ { "txid": "'$utxo_txid_0'", "vout": '$utxo_vout_0', "sequence":1}, {"txid": "'$utxo_txid_1'", "vout": '$utxo_vout_1', "sequence":1}  ]''' outputs='''[{ "'$address_traderrecibido'": 70 },{ "'$address_minercambio'": 29.99999 }]''')
echo "creamos una transaccion en crudo donde enviamos 70BTC a Trader=Recibido desde Miner y 29.99999 a Miner=Cambio"

#FIrmando y Transmision.
echo "Transaccion en crudo(hex) donde se envia 70 a Trader: $txParent"

toSingtx=$(bitcoin-cli -rpcwallet=Miner signrawtransactionwithwallet $txParent | jq -r '.hex')
echo "transaccion firmada"

parent=$(bitcoin-cli sendrawtransaction $toSingtx)
echo "La transaccion se ha enviado su identificación es $parent"

echo "Muestra el id de la transaccion padre $parent"
#Consulta a la mempool nuestra transaccion, se debe obtener los datos para armar el json

#Primero vemos todos los valores que necesitamos
echo "Punto 5.Realizar consultas al "mempool" del nodo para obtener los detalles de la transacción parent"

input_trader=$(bitcoin-cli decoderawtransaction $signed_parent | jq -r '.vin[0] | { txid: .txid, vout: .vout }')
input_miner=$(bitcoin-cli decoderawtransaction $signed_parent | jq -r '.vin[1] | { txid: .txid, vout: .vout }')

output_trader=$(bitcoin-cli decoderawtransaction $signed_parent | jq -r '.vout[0] | { script_pubkey: .scriptPubKey.hex , amount: .value }')

output_miner=$(bitcoin-cli decoderawtransaction $signed_parent | jq -r '.vout[1] | { script_pubkey: .scriptPubKey.hex , amount: .value }')
		
tx_fee=$(bitcoin-cli getmempoolentry $txid_parent | jq -r '.fees .base')

tx_weight=$(bitcoin-cli getmempoolentry $txid_parent | jq -r '.vsize')

json='{ "input": [ '$input_trader', '$input_miner' ], "output": [ '$output_miner', '$output_trader' ], "Fees": '$tx_fee', "Weight": '$tx_weight' }'

echo "Imprime el JSON anterior en la terminal."
echo $json | jq

echo "Vamos a crear la transaccion child que gaste uno de las salidas de la transaccion parent anterior"
changeaddress_2=$(bitcoin-cli -rpcwallet=Miner getrawchangeaddress)

child=$(bitcoin-cli -named createrawtransaction inputs='''[ { "txid": "'$txid_parent'", "vout": '1' } ]''' outputs='''{ "'$changeaddress_2'": 29.99998 }''')

signed_child=$(bitcoin-cli -rpcwallet=Miner signrawtransactionwithwallet $child | jq -r '.hex')

txid_child=$(bitcoin-cli sendrawtransaction $signed_child)

bitcoin-cli decoderawtransaction $signed_parent

echo "Punto 8. A continuacion los detalles de la transaccion child en la mempool mediante el comando getmempoolentry"
bitcoin-cli getmempoolentry $txid_child

echo "Punto 9. Vamos a aumentar la tarifa de la transaccion parent usando RBF"

parent_rbf=$(bitcoin-cli -named createrawtransaction inputs='''[ { "txid": "'$utxo_txid_1'", "vout": '$utxo_vout_1', "sequence": 1}, { "txid": "'$utxo_txid_2'", "vout": '$utxo_vout_2' } ]''' outputs='''{ "'$recipient'": 70.00000, "'$changeaddress'": 29.9999 }''')

echo "Punto 10. Firmamos y transmitimos la transaccion"

signed_parent_rbf=$(bitcoin-cli -rpcwallet=Miner signrawtransactionwithwallet $parent_rbf | jq -r '.hex')
txid_parent_rbf=$(bitcoin-cli sendrawtransaction $signed_parent_rbf)


echo "Punto 11. Consultar transaccion child"

bitcoin-cli getmempoolentry $txid_child
echo "La transaccion child no se encuentra en la mempool"
bitcoin-cli getmempoolentry $txid_parent
echo "La transaccion parent tampoco se encuentra en la mempool"


bitcoin-cli stop
echo       Bitcoin Core stopping

fin...
