## Moved

Documentation now moved to [https://docs.meshcore.io/companion_protocol/](https://docs.meshcore.io/companion_protocol/)

Info below may be outdated.

## Intro

In the `examples/companion_radio` folder is a firmware project within MeshCore, for a radio to act as companion to external apps, either mobile, web or whatever.

There are two variants: USB and BLE.

Both have a simple protocol consisting of 'frames' described below, where (for simplicity) the frames are delimited by:
* For BLE - a frame is simply a single characteristic value (BLE link layer already does all the integrity checks)
* For USB - an _outbound_ frame from starts with byte 62 (ASCII **'>'**), then 2 bytes with frame length (little-endian), followed by actual frame. An _inbound_ frame starts with byte 60 (ASCII **'<'**), then 2 bytes with frame length, followed by actual frame.

NOTE: _outbound_ means radio -> app. _inbound_ means app -> radio.

The companion radio essentially takes the 'server' role, and just responds to requests from the connected app (the 'client').

## App Commands/Requests

**CMD_DEVICE_QEURY** (22)

This should be first command app sends after establishing connection. Radio responds with RESP_CODE_DEVICE_INFO(13)

**CMD_APP_START** (1)

The app start command should be the _first_ request the app sends to the radio. The radio should respond with a RESP_CODE_SELF_INFO(5)

**CMD_GET_CONTACTS** (4)

The app sends this request to sync the contacts list. Optionally can encode a 32-bit 'since' param, where radio will only return contacts which have been modified _since_ that timestamp. The radio will send a sequence of frames: RESP_CODE_CONTACTS_START(2), RESP_CODE_CONTACT(3) .. {for each modified/new contact}, RESP_CODE_END_OF_CONTACTS(4).

**CMD_GET_DEVICE_TIME** (5)

App sends this to receive the clock (as epoch secs, UTC) on the device. Responds with RESP_CODE_CURR_TIME(9) + 32-bit unsigned value.

**CMD_SET_DEVICE_TIME** (6)

App sends this (with 32-bit unsigned param) to set the clock on the device. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SEND_SELF_ADVERT** (7)

App sends for radio to send an Advertisement packet. (optional byte param value 1, to send flood-mode, otherwise sends zero-hop). Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SET_ADVERT_NAME** (8)

App sends to update the name for this node, as used in the advertisement packets. Request includes the new name (remainder of frame). Responds with RESP_CODE_OK(0)

**CMD_SET_ADVERT_LATLON** (14)

App sends to update the lat/lon for this node, as used in the advertisement packets. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SYNC_NEXT_MESSAGE** (10)

App sends to get the next text message from the radio's message queue. (these can queue up even while the app is disconnected) If queue is empty, replies with RESP_CODE_NO_MORE_MESSAGES(10). Otherwise, either a RESP_CODE_CONTACT_MSG_RECV(7) or RESP_CODE_CHANNEL_MSG_RECV(8) is returned. After processing these, the app would typically send another CMD_SYNC_NEXT_MESSAGE request to pull the next from queue, etc. Also, app should send this request upon getting the _push_ notification PUSH_CODE_MSG_WAITING(0x83).
Ver 3+ app clients receive newer response frames: RESP_CODE_CONTACT_MSG_RECV_V3(16) and RESP_CODE_CHANNEL_MSG_RECV_V3(17).

**CMD_ADD_UPDATE_CONTACT** (9)

App sends this either to modify a contact or add a new one. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_REMOVE_CONTACT** (15)

App sends this to remove a contact (app provides public key of contact). Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SHARE_CONTACT** (16)

App sends this to share a contact by zero-hop sending original advert packet (app provides public key of contact). Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_EXPORT_CONTACT** (17)

(This is for 'business card' support) App sends this to obtain the last raw advert for given contact (pub key follows), OR if no contact specified creates a NEW advert for THIS node. Responds with either RESP_CODE_EXPORT_CONTACT(11) or RESP_CODE_ERR(1)

**CMD_IMPORT_CONTACT** (18)

App sends this (followed by bytes obtained by CMD_EXPORT_CONTACT) to manually import a contact (usually via a 'business card' exchange). Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1), if successful will then result in PUSH_CODE_ADVERT as if receiving an advert (typically, then trigger the contacts sync as usual to update contacts list)

**CMD_REBOOT** (19)

App sends this (followed by text 'reboot') to cause the companion device to reboot. (does not respond)

**CMD_GET_BATT_AND_STORAGE** (20)

App sends to get the device's battery milli volts, and storage stats. Responds with RESP_CODE_BATT_AND_STORAGE(12).

**CMD_SET_TUNING_PARAMS** (21)

App sends to set various 'tuning' parameters. Responds with RESP_CODE_OK(0)

**CMD_SET_OTHER_PARAMS** (38)

App sends to set various other parameters. Responds with RESP_CODE_OK(0)

**CMD_SEND_TXT_MSG** (2)

App sends to radio for a text message send to a given contact. (DM) Responds with RESP_CODE_SENT(6) + a 32-bit 'expected ACK' code, or RESP_CODE_ERR(1)

**CMD_SEND_CHANNEL_TXT_MSG** (3)

App sends to radio to send flood-mode text message to a channel.  Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SET_RADIO_PARAMS** (11)

App sends to radio to save new radio parameters to its storage. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1). 

**CMD_SET_RADIO_TX_POWER** (12)

App sends to radio to set the radio TX power level. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1). 

**CMD_RESET_PATH** (13)

App sends to radio along with the public key of the contact, to reset the out_path. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SEND_RAW_DATA** (25)

App sends to radio to transmit a packet with PAYLOAD_TYPE_RAW_CUSTOM with given payload and path. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1)

**CMD_SEND_LOGIN** (26)

App sends to radio to send a login request to a repeater or room server. Responds with RESP_CODE_SENT(6) (along with estimated timeout) or RESP_CODE_ERR(1). When response is received, PUSH_CODE_LOGIN_SUCCESS(0x85) or PUSH_CODE_LOGIN_FAIL(0x86) is sent to app. Login fail is usually just a timeout, at present.

**CMD_SEND_STATUS_REQ** (27)

App sends to radio to send a status request to a repeater or sensor. Responds with RESP_CODE_SENT(6) (along with estimated timeout) or RESP_CODE_ERR(1). When response is received, PUSH_CODE_STATUS_RESPONSE(0x87) is sent to app.

**CMD_SEND_TRACE_PATH** (36)

App sends to radio to initiate a TRACE packet to follow a given path, and collect SNR data. Responds with either RESP_CODE_SENT(6) or RESP_CODE_ERR(1). App provides a random 32-bit 'tag', which is reflected in the received TRACE packet, via a PUSH_CODE_TRACE_DATA.

**CMD_SEND_TELEMETRY_REQ** (39)

App sends to radio to send a telemetry request to given node. Responds with RESP_CODE_SENT(6) (along with estimated timeout) or RESP_CODE_ERR(1). When telemetry is received, PUSH_CODE_TELEMETRY_RESPONSE(0x8B) is sent to app.  (NOTE: newer CMD_SEND_BINARY_REQ (50) can be used instead of this)

**CMD_GET_CUSTOM_VARS** (40)

App sends to radio to retrieve current state of ALL custom variables. Responds with RESP_CODE_CUSTOM_VARS(21) (along with comma separated name:value pairs as text).

**CMD_SET_CUSTOM_VAR** (41)

App sends to radio to set new state of a single custom variable, with name:value as text following the cmd code. Responds with ERR_CODE_ILLEGAL_ARG or RESP_CODE_OK.

**CMD_GET_ADVERT_PATH** (42)

App sends to radio to to query if the last advert path for a given contact is known. Responds with either RESP_CODE_ADVERT_PATH(22), or RESP_CODE_ERR if not found/known.

**CMD_GET_TUNING_PARAMS** (43)

App sends to radio to retrieve the current airtime-factor and rx-delay settings. Responds with RESP_CODE_TUNING_PARAMS, which has same structure as the CMD_SET_TUNING_PARAMS frame.

**CMD_SEND_BINARY_REQ** (50)

App sends to radio to send a binary request to given node. Responds with RESP_CODE_SENT(6) (along with TAG + estimated timeout) or RESP_CODE_ERR(1). When response is received, PUSH_CODE_BINARY_RESPONSE(0x8C) is sent to app.

**CMD_FACTORY_RESET** (51)

App sends to radio to erase the flash file system. Command should have the ASCII bytes "reset" following the command code.

**CMD_SEND_CONTROL_DATA** (55)

App sends to radio to transmit a packet with PAYLOAD_TYPE_CONTROL with given payload. Responds with either RESP_CODE_OK(0) or RESP_CODE_ERR(1).

**CMD_GET_STATS** (56)

App sends to radio to retrieve statistics. Command code is followed by a sub-type byte: 0=CORE, 1=RADIO, 2=PACKETS. Responds with RESP_CODE_STATS (24).

**CMD_GET_ALLOWED_REPEAT_FREQ** (60)

App sends to radio to get list of allowed frequency ranges which off-grid/client-repeat mode is allowed. Responds with RESP_ALLOWED_REPEAT_FREQ (26).

## Push Notifications

These can be pushed to the app at any time:
* PUSH_CODE_ADVERT (0x80)  - sent when a new advertisement packet was received. Includes 32-byte public key of node. (for full details, repeat the contacts sync flow described with the CMD_GET_CONTACTS request, ideally passing 'since' param)
* PUSH_CODE_PATH_UPDATED (0x81)  - sent when a contact has received a new path. Includes 32-byte public key of node. (trigger contacts sync flow, as above)
* PUSH_CODE_SEND_CONFIRMED (0x82)  - sent when a matching message ACK is received. Includes 32-bit ACK code, and 32-bit round-trip time in milliseconds.
* PUSH_CODE_MSG_WAITING (0x83)  - sent when a new text message has been received. App should trigger the flow mentioned with the CMD_SYNC_NEXT_MESSAGE request.
* PUSH_CODE_RAW_DATA (0x84)  - sent when a packet with PAYLOAD_TYPE_RAW_CUSTOM is received. (direct)
* PUSH_CODE_LOGIN_SUCCESS (0x85)  - sent when a successful login response is received.
* PUSH_CODE_LOGIN_FAIL (0x86)  - sent when a login fail response is received.
* PUSH_CODE_STATUS_RESPONSE (0x87)  - sent when a status response is received.
* PUSH_CODE_TRACE_DATA (0x89)  - sent when a TRACE packet is received which has reached end of its given path.
* PUSH_CODE_NEW_ADVERT (0x8A)  - sent when manual_add_contacts=1 and a new contact advert is received. Same format as RESP_CODE_CONTACT.
* PUSH_CODE_TELEMETRY_RESPONSE (0x8B)  - sent when a telemetry response is received.
* PUSH_CODE_BINARY_RESPONSE (0x8C)  - sent when a binary response is received. (NOTE: matched by TAG)
* PUSH_CODE_CONTROL_DATA (0x8E)  - sent when a CONTROL packet is received

## Frame Formats/Structures

NOTE: all uint32 values are Little Endian!

```
CMD_DEVICE_QEURY {
  code: byte,     // constant: 22
  app_target_ver: byte   // version of serial protocol the app understands
}
```

```
RESP_CODE_DEVICE_INFO {
  code: byte,     // constant: 13
  firmware_ver: byte,
  max_contacts_div_2: byte,     // ver 3+
  max_channels: byte,           // ver 3+
  ble_pin: uint32,              // ver 3+. (BLE pin code)
  firmware_build_date: chars(12),    // ASCII-null terminated, eg. "19 Feb 2025"
  manufacturer_model: chars(40),     // ASCII-null terminated
  semantic_version: chars(20)        // ASCII-null terminated
}
```

```
CMD_APP_START {
  code: byte,     // constant: 1
  app_ver: byte,
  reserved: bytes(6),
  app_name: varchar   // remainder of frame 
}
```

```
RESP_CODE_SELF_INFO {
  code: byte,   // constant: 5
  type: byte,   // one of ADV_TYPE_*
  tx_power_dbm: byte    // current TX power, in dBm
  max_tx_power: byte,     // max TX power radio supports
  public_key: bytes(32),
  adv_lat: int32,   // advert latitude * 1E6
  adv_lon: int32,   // advert longitude * 1E6
  multi_acks: byte,     // 0 = no extra ACKs, 1 = send extra ACK
  advert_loc_policy: byte,    // 0 = don't share, 1 = share
  telemetry_modes: byte,    // bits: 0..1 = Base mode, bits: 2..3 = Location mode. (modes: 0 = DENY, 1 = apply contact.flags, 2 = ALLOW ALL)
  manual_add_contacts: byte,    // 0 or 1
  radio_freq: uint32,    // freq * 1000
  radio_bw: uint32,      // bandwidth(khz) * 1000
  radio_sf: byte,        // spreading factor
  radio_cr: byte,        // coding rate
  name: varchar   // remainder of frame
}
```

```
CMD_GET_CONTACTS {
  code: byte,   // constant 4
  (optional) since: uint32,   // the last contact.lastmod value already received
}
```

```
RESP_CODE_CONTACTS_START {
  code: byte,   // constant 2
  count: uint32    // total number of contacts
}
```

```
RESP_CODE_CONTACT {
  code: byte,    // constant 3
  public_key: bytes(32),
  type: byte,   // one of ADV_TYPE_*
  flags: byte,
  out_path_len: signed-byte,
  out_path: bytes(64),
  adv_name: chars(32),    // advertised  name (null terminated)
  last_advert: uint32,
  adv_lat: int32,    // advertised latitude * 1E6
  adv_lon: int32,    // advertised longitude * 1E6
  lastmod: uint32
}
```

```
RESP_CODE_END_OF_CONTACTS {
  code: byte,     // constant 4
  most_recent_lastmod: uint32     // used this for next 'since' param to CMD_GET_CONTACTS
}
```

```
CMD_SET_DEVICE_TIME {
  code: byte,   // constant 6
  epoch_secs: uint32
}
```

```
RESP_CODE_CURR_TIME {
  code: byte,   // constant 9
  epoch_secs: uint32
}
```

```
CMD_SEND_SELF_ADVERT {
  code: byte,   // constant 7
  (optional) type: byte,   // 1 = flood, 0 = zero-hop (default)
}
```

```
CMD_SET_ADVERT_NAME {
  code: byte,   // constant 8
  name: varchar   // remainder of frame
}
```

```
CMD_SET_ADVERT_LATLON {
  code: byte,    // constant 14
  adv_lat: int32,    // latitude * 1E6
  adv_lon: int32,    // longitude * 1E6
  adv_alt: int32   // OPTIONAL (for future support)
}
```

```
CMD_ADD_UPDATE_CONTACT {
  code: byte,   // constant 9
  public_key: bytes(32),
  type: byte,   // one of ADV_TYPE_*
  flags: byte,
  out_path_len: signed-byte,
  out_path: bytes(64),
  adv_name: chars(32),    // null terminated
  last_advert: uint32
  (optional) adv_lat: int32,    // advertised latitude * 1E6
  (optional) adv_lon: int32,    // advertised longitude * 1E6
}
```

```
CMD_REMOVE_CONTACT { 
  code: byte,   // constant 15
  public_key: bytes(32)
}
```

```
CMD_SHARE_CONTACT { 
  code: byte,   // constant 16
  public_key: bytes(32)
}
```

```
CMD_EXPORT_CONTACT {
  code: byte,   // constant 17
  (optional) public_key: bytes(32)   // public key of contact (if omitted, export SELF)
}
```

```
RESP_CODE_EXPORT_CONTACT {
  code: byte,   // constant 11
  card_data: bytes   // remainder of frame. ('business card' format as: "meshcore://{hex(card_data)}" )
}
```

```
CMD_IMPORT_CONTACT {
  code: byte,   // constant 18
  card_data: bytes   // remainder of frame.
}
```

```
CMD_RESET_PATH {
  code: byte,    // constant 13
  public_key: bytes(32)
}
```

```
CMD_SEND_TXT_MSG {
  code: byte,   // constant 2
  txt_type: byte,     // one of TXT_TYPE_*  (0 = plain)
  attempt: byte,     // values: 0..3 (attempt number)
  sender_timestamp: uint32,
  pubkey_prefix: bytes(6),     // just first 6 bytes of recipient contact's public key
  text: varchar    // remainder of frame  (max length: 160 bytes)
}
```

```
CMD_SEND_CHANNEL_TXT_MSG {
  code: byte,   // constant 3
  txt_type: byte,     // one of TXT_TYPE_*  (0 = plain)
  channel_idx: byte,     // reserved (0 for 'public')
  sender_timestamp: uint32,
  text: varchar    // remainder of frame. (max length: 160 - len(advert_name) - 2 )
}
```

```
RESP_CODE_SENT {
  code: byte,   // constant 6
  type: byte,    // how it was sent: 1 = flood, 0 = direct
  expected_ack_or_tag: bytes(4),
  suggested_timeout: uint32   // estimated round-trip timeout, in milliseconds
}
```

```
PUSH_CODE_SEND_CONFIRMED {
  code: byte,     // constant 0x82
  ack_code: bytes(4),
  round_trip: uint32   // milliseconds
}
```

```
RESP_CODE_CONTACT_MSG_RECV {
  code: byte,   // constant 7
  pubkey_prefix: bytes(6),     // just first 6 bytes of sender's public key
  path_len: byte,     // 0xFF if was sent direct, otherwise hop count for flood-mode
  txt_type: byte,     // one of TXT_TYPE_*  (0 = plain)
  sender_timestamp: uint32,
  text: varchar    // remainder of frame  
}
```

```
RESP_CODE_CONTACT_MSG_RECV_V3 {
  code: byte,   // constant 16
  snr: byte,     // SNR*4
  reserved: bytes(2),   // zeroes
  pubkey_prefix: bytes(6),     // just first 6 bytes of sender's public key
  path_len: byte,     // 0xFF if was sent direct, otherwise hop count for flood-mode
  txt_type: byte,     // one of TXT_TYPE_*  (0 = plain)
  sender_timestamp: uint32,
  text: varchar    // remainder of frame  
}
```

```
RESP_CODE_CHANNEL_MSG_RECV {
  code: byte,   // constant 8
  channel_idx: byte,   // reserved (0 for now, ie. 'public')
  path_len: byte,     // 0xFF if was sent direct, otherwise hop count for flood-mode
  txt_type: byte,     // one of TXT_TYPE_*  (0 = plain)
  sender_timestamp: uint32,
  text: varchar    // remainder of frame  
}
```

```
RESP_CODE_CHANNEL_MSG_RECV_V3 {
  code: byte,   // constant 17
  snr: byte,     // SNR*4
  reserved: bytes(2),   // zeroes
  channel_idx: byte,   // reserved (0 for now, ie. 'public')
  path_len: byte,     // 0xFF if was sent direct, otherwise hop count for flood-mode
  txt_type: byte,     // one of TXT_TYPE_*  (0 = plain)
  sender_timestamp: uint32,
  text: varchar    // remainder of frame  
}
```

```
CMD_SET_RADIO_PARAMS {
  code: byte,   // constant 11
  radio_freq: uint32,    // freq * 1000
  radio_bw: uint32,      // bandwidth(khz) * 1000
  radio_sf: byte,        // spreading factor
  radio_cr: byte,         // coding rate
  repeat_mode: byte       // (since ver 9+) boolean, enable off-grid (client repeat) mode
}
```

```
CMD_SET_RADIO_TX_POWER {
  code: byte,   // constant 12
  tx_power_dbm: byte    // TX power, in dBm
}
```

```
CMD_SET_TUNING_PARAMS {    // RESP_CODE_TUNING_PARAMS uses same
  code: byte,   // constant 21
  rxdelay_base: uint32,    // rxdelay * 1000
  airtime_factor: uint32   // airtime factor * 1000
  reserved: bytes(8)    // set to zero
}
```

```
CMD_SET_OTHER_PARAMS {
  code: byte,   // constant 38
  manual_add_contacts: byte,    // 0 or 1
  telemetry_modes: byte,      // v5+ (optional)
  advert_loc_policy: byte,    // v5+ (optional)
  multi_acks: byte            // v7+ (optional)   0 = no extra ACKs, 1 = send extra ACK
}
```

```
RESP_CODE_BATT_AND_STORAGE {
  code: byte,    // constant 12
  milli_volts: uint16,
  used_kb: uint32,   // optional
  total_kb: uint32   // optional (zero if unknown, or not supported)
}
```

```
CMD_SEND_RAW_DATA {
  code: byte,    // constant 25
  path_len: byte,
  path: bytes(path_len),   // variable len
  payload: bytes    // remainder of frame
}
```

```
PUSH_CODE_RAW_DATA {
  code: byte,    // constant 0x84
  SNR_mult_4: signed-byte,     // SNR * 4
  RSSI: signed-byte,
  reserved: byte,     // constant 0xFF
  payload: bytes     // remainder of frame
}
```

```
CMD_SEND_LOGIN {
  code: byte,    // constant 26
  pub_key: bytes(32),     // id of repeater or room server
  password: varchar     // remainder of frame (max 15 bytes)
}
```

```
PUSH_CODE_LOGIN_SUCCESS {
  code: byte,    // constant 0x85
  permissions: byte,     // is_admin if lowest bit is 1
  pub_key_prefix: bytes(6)     // public key prefix (first 6 bytes)
  tag: int32,
  new_permissions: byte     // V7+
}
```

```
CMD_SEND_STATUS_REQ {
  code: byte,    // constant 27
  pub_key: bytes(32)     // id of repeater or sensor
}
```

```
PUSH_CODE_STATUS_RESPONSE {
  code: byte,    // constant 0x87
  reserved: byte,   // zero
  pub_key_prefix: bytes(6),     // public key prefix (first 6 bytes)
  status_data:   bytes     // remainder of frame
}
```

```
CMD_SEND_TELEMETRY_REQ {
  code: byte,       // constant 39
  reserved: bytes(3),   // zeroes
  pub_key: bytes(32)     // id of destination node
}
```

```
PUSH_CODE_TELEMETRY_RESPONSE {
  code: byte,    // constant 0x8B
  reserved: byte,   // zero
  pub_key_prefix: bytes(6),     // public key prefix (first 6 bytes)
  LPP_sensor_data:   bytes     // remainder of frame
}
```

```
PUSH_CODE_BINARY_RESPONSE {
  code: byte,    // constant 0x8C
  reserved: byte,   // zero
  tag: uint32,     // match to RESP_CODE_SENT 'expected_ack_or_tag' property
  response_data:   bytes     // remainder of frame
}
```

```
CMD_SEND_TRACE_PATH {
  code: byte,    // constant 36
  tag: int32,         // random set by initiator tag
  auth_code: int32,   // optional: something to authenticate this TRACE
  flags: byte,      // zero for now
  path: bytes      // remainder of frame, the hashes of path for this TRACE to follow
}
```

```
PUSH_CODE_TRACE_DATA {
  code: byte,    // constant 0x89
  reserved: byte,    // zero
  path_len: byte,
  flags: byte,    // zero for now
  tag: int32,
  auth_code: int32,
  path_hashes:  bytes(path_len),   // variable len
  path_snrs: bytes(path_len+1)    // variable len (last byte is SNR for LAST hop to this node) [each byte = SNR * 4]
}
```

```
CMD_SET_DEVICE_PIN {
  code: byte,    // constant 37
  ble_pin: uint32
}
```

```
RESP_CODE_ERR {
  code: byte,     // constant: 1
  err_code: byte
}
```

```
CMD_GET_ADVERT_PATH {
  code: byte,    // constant: 42
  reserved: byte,    // zero
  pub_key: bytes(32)   // public key of contact being queried
}
```

```
RESP_CODE_ADVERT_PATH {
  code: byte,     // constant: 22
  recv_timestamp: uint32,    // by local clock
  path_len: byte,
  path:   bytes(path_len)
}
```

```
CMD_SEND_BINARY_REQ {
  code: byte,    // constant: 50
  pub_key: bytes(32)   // public key of contact to send request to
  request_code_and_params: bytes    // remainder of frame
}
```

```
CMD_SEND_CONTROL_DATA {
  code: byte,   // constant 55
  flags: byte,    // must be zero
  sub_type: byte,       // 0x80 = DISCOVER_REQ
  payload: bytes     // remainder of frame
}
```

```
PUSH_CODE_CONTROL_DATA {
  code: byte,     // constant 0x8E
  SNR_mult_4: signed-byte,     // SNR * 4
  RSSI: signed-byte,
  path_len: byte,     // (always zero at present)
  path:  bytes(path_len),    // (optional) skip if path_len is 0
  payload: bytes     // remainder of frame  
}
```

```
RESP_CODE_STATS {
  code: byte,   // constant 24
  sub_type: byte,    // 0=CORE, 1=RADIO, 2=PACKETS
  VARIANT {   // sub_type=0
    batt_millivolts: int16,
    uptime_secs: uint32,
    err_flags: uint16,
    queue_len: byte
  }
  VARIANT {   // sub_type=1
    noise_floor: int16,
    last_rssi:  int8,
    last_snr: int8,   // SNR x 4
    tx_air_time: uint32,   // seconds
    rx_air_time: uint32   // seconds
  }
  VARIANT {   // sub_type=2
    num_recv_packets: uint32,
    num_sent_packets: uint32,
    num_sent_flood: uint32,
    num_sent_direct: uint32,
    num_recv_flood: uint32,
    num_recv_direct: uint32,
  }
}
```

```
RESP_ALLOWED_REPEAT_FREQ {
  code: byte,   // constant 26
  ranges: ARRAY OF {      // remainder of frame
    lower_freq: uint32,      // Freq * 1000
    upper_freq: uint32       // Freq * 1000
  }
}
```

## Constants

_adv_type:_
* ADV_TYPE_NONE        = 0
* ADV_TYPE_CHAT        = 1
* ADV_TYPE_REPEATER    = 2
* ADV_TYPE_ROOM        = 3

_txt_type:_
* TXT_TYPE_PLAIN         = 0    // a plain text message
* TXT_TYPE_CLI_DATA      = 1    // a CLI command
* TXT_TYPE_SIGNED_PLAIN  = 2    // plain text, signed by sender

_err_code:_
* ERR_CODE_UNSUPPORTED_CMD     = 1
* ERR_CODE_NOT_FOUND           = 2
* ERR_CODE_TABLE_FULL          = 3
* ERR_CODE_BAD_STATE           = 4
* ERR_CODE_FILE_IO_ERROR       = 5
* ERR_CODE_ILLEGAL_ARG         = 6
