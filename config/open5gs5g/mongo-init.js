db = db.getSiblingDB('open5gs');
const imsi = '208990100001100';
db.subscribers.deleteOne({ imsi });
db.subscribers.insertOne({
  _id: ObjectId(),
  schema_version: NumberInt(1),
  imsi,
  msisdn: [],
  imeisv: [],
  mme_host: [],
  mm_realm: [],
  purge_flag: [],
  slice: [{
    sst: NumberInt(1),
    sd: 'ffffff',
    default_indicator: true,
    session: [{
      name: 'oai',
      type: NumberInt(3),
      qos: {
        index: NumberInt(9),
        arp: {
          priority_level: NumberInt(8),
          pre_emption_capability: NumberInt(1),
          pre_emption_vulnerability: NumberInt(2)
        }
      },
      ambr: {
        downlink: { value: NumberInt(1000000000), unit: NumberInt(0) },
        uplink: { value: NumberInt(1000000000), unit: NumberInt(0) }
      },
      pcc_rule: [],
      _id: ObjectId()
    }],
    _id: ObjectId()
  }],
  security: {
    k: 'fec86ba6eb707ed08905757b1bb44b8f',
    op: null,
    opc: 'c42449363bbad02b66d16bc975d77cc1',
    amf: '8000'
  },
  ambr: {
    downlink: { value: NumberInt(1000000000), unit: NumberInt(0) },
    uplink: { value: NumberInt(1000000000), unit: NumberInt(0) }
  },
  access_restriction_data: NumberInt(32),
  network_access_mode: NumberInt(0),
  subscriber_status: NumberInt(0),
  operator_determined_barring: NumberInt(0),
  subscribed_rau_tau_timer: NumberInt(12),
  __v: NumberInt(0)
});
print(`seeded Open5GS subscriber ${imsi}`);
