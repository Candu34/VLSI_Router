# Router APB Multi-Port în SystemVerilog

Proiect de verificare pentru un router de pachete multi-port, implementat în **SystemVerilog**, cu:
- interfață **APB** pentru configurare și monitorizare,
- interfață **Req/Ack** pentru recepția pachetelor,
- **4 FIFO-uri** independente pentru bufferizare,
- **4 instanțe UART TX** pentru transmiterea serială a datelor.

## Descriere generală

Router-ul primește pachete de **32 de biți** prin interfața de intrare și le direcționează către unul dintre cele 4 canale de ieșire, în funcție de adresa de destinație. Fiecare canal are propriul FIFO și propriul controler UART TX. Interfața APB permite configurarea baudrate-ului UART și citirea registrelor de stare și a contoarelor interne. 

## Structura pachetului

Pachetul de intrare are 32 de biți și următoarea structură:

- **[31:28]** – adresa de destinație
- **[27:24]** – adresa sursă
- **[23:22]** – prioritate
- **[21:20]** – tip pachet
- **[19:16]** – număr de secvență
- **[15:0]** – payload

Destinațiile valide sunt **0–3**. Orice destinație mai mare decât 3 duce la eliminarea pachetului și incrementarea contorului de pachete eliminate. 

## Arhitectura proiectului

### Module principale

- `router.sv` – modul top-level; integrează APB, parserul de pachete, FIFO-urile, FSM-urile TX și instanțele UART
- `fifo_memory.sv` – memorie FIFO parametrizabilă
- `uart.sv` – modul UART cu transmisie TX și baudrate configurabil
- `tb/` – director pentru testbench și mediul de verificare 

### Blocuri funcționale din DUT

- APB write logic
- APB read logic
- packet parser
- contor pachete acceptate
- contor pachete eliminate
- logică `ack_o`
- 4 FSM-uri TX, câte unul per canal
- registru de status FIFO 

## Interfețe

### Interfața de sistem
- `clk_i` – semnal de ceas
- `rst_n_i` – reset asincron activ pe 0

### Interfața APB
- `psel_i`
- `penable_i`
- `pr_w_i`
- `paddr_i[7:0]`
- `pwdata_i[7:0]`
- `prdata_o[7:0]`
- `p_error_o`
- `p_ready_o`

### Interfața Router
- `data_in[31:0]`
- `req_i`
- `ack_o`

### Interfața UART
- `uart_tx_o[3:0]` – 4 ieșiri TX, câte una pentru fiecare port valid 

## Funcționalități implementate

- recepție de pachete de 32 biți prin interfața Req/Ack
- parsare pachet conform structurii definite
- rutare către FIFO-ul asociat destinației
- eliminare pachete cu destinație invalidă
- eliminare pachete la FIFO plin
- transmisie serială prin 4 canale UART TX
- configurare baudrate prin APB
- citire status și contoare prin APB
- reset asincron pentru registre, FIFO-uri și FSM-uri 

## Parametri locali

În `router.sv` sunt definiți următorii parametri:

- `APB_MEMORY_SIZE = 6`
- `NUM_FIFOS = 4`
- `FIFO_SIZE = 8`
- `FIFO_WIDTH = 32`

Aceste valori definesc numărul de regiștri APB, numărul de FIFO-uri, capacitatea fiecărui FIFO și lățimea datelor stocate. 

## Harta registrelor APB

| Adresă | Registru        | Acces | Descriere |
|--------|------------------|-------|-----------|
| `0x00` | `CTRL`           | R/W   | enable/reset router |
| `0x01` | `UART_CLK_DIV`   | R/W   | configurare baudrate UART |
| `0x02` | rezervat         | —     | nefolosit |
| `0x03` | `PKT_CNT`        | R     | contor pachete acceptate |
| `0x04` | `PKT_SKIP_CNT`   | R     | contor pachete eliminate |
| `0x05` | `STATUS`         | R     | biți FULL/EMPTY pentru FIFO-uri |

Registrul `STATUS` codifică starea FIFO-urilor pe biți, câte 2 biți per FIFO. 

## Protocol de funcționare

### Req/Ack
Inițiatorul pune un pachet valid pe `data_in` și ridică `req_i`. Router-ul răspunde cu `ack_o` pentru un tact. Dacă destinația este validă și FIFO-ul nu este plin, pachetul este înscris. Dacă nu, este eliminat și incrementat `PKT_SKIP_CNT`. 

### APB
Transferurile respectă fazele:
- **SETUP**: `psel=1`, `penable=0`
- **ACCESS**: `psel=1`, `penable=1`

Interfața APB este folosită pentru configurarea router-ului și citirea registrelor interne.

### UART
Fiecare canal de ieșire are propriul controler UART TX. Modulul UART implementează transmisie serială asincronă și suportă:
- lungimi de date configurabile: 8/16/32/64 biți
- transmisie LSB-first sau MSB-first
- baudrate configurabil prin APB 

## Verificare

Mediul de verificare include:
- agent APB
- agent Req/Ack pentru router
- agent UART/Reset
- monitoare pentru fiecare interfață
- scoreboard / model de referință
- colectori de coverage
- checkere și aserțiuni funcționale 

### Exemple de checkere
- `route_check`
- `skip_invalid_check`
- `skip_full_check`
- `pkt_cnt_check`
- `apb_rd_check`
- `apb_wr_check`
- `uart_baud_check`
- `fifo_status_check`
- `fifo_order_check`
- `uart_tx_data_check`
- `reset_check` 

### Exemple de teste
- `apb_wr_baud_test`
- `apb_rd_all_regs_test`
- `apb_invalid_addr_test`
- `apb_ro_write_test`
- `route_port0_test`
- `route_port1_test`
- `route_port2_test`
- `route_port3_test`
- `route_all_ports_test`
- `invalid_dest_test`
- `fifo_overflow_test`
- `fifo_status_test`
- `pkt_cnt_test`
- `reset_async_test`
- `uart_tx_baud_test`
- `uart_tx_data_test`
- `back_to_back_test`
- `baud_change_during_tx_test`
- `multi_port_concurrent_test`
- `random_directed_test`
- `random_stress_test` 

## Limitări cunoscute

- sunt suportate doar 4 porturi de destinație
- FIFO-ul are doar 8 intrări
- contoarele APB sunt pe 8 biți și fac wrap-around după 255
- câmpul de prioritate există în pachet, dar nu este încă folosit pentru arbitrare
- `ack_o` poate fi afirmat chiar dacă pachetul este eliminat
- UART-ul implementat este doar TX, fără RX 

## Direcții viitoare

- implementarea prioritizării reale pe baza câmpului `prio`
- extinderea contoarelor APB la 16 biți
- adăugarea unui mecanism de back-pressure
- implementarea unei căi UART RX
- adăugarea unui mecanism CRC
- verificare formală cu proprietăți SVA
- extinderea la mai multe porturi prin parametrizare completă 

## Autori

- **Brujbeanu Gabriel-Lucian**
- **Candu Ion**

## Resurse

- **GitHub:** `https://github.com/Candu34/VLSI_Router`
- **EDA Playground:** `https://edaplayground.com/x/6mcW` 