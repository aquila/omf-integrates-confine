mysql -uomf -pomf << EOF
use inventory;
truncate locations;
truncate testbeds;
truncate nodes;
truncate pxeimages;
truncate motherboards;
truncate devices;

INSERT INTO pxeimages (id, image_name, short_description) VALUES
(1, 'omf-5.4', '5.4 PXE image');

INSERT INTO motherboards (id, inventory_id, mfr_sn, cpu_type, cpu_n, cpu_hz, hd_sn, hd_size, hd_status, memory) VALUES
(1, 1, NULL, NULL, 1, NULL, NULL, NULL, 1, NULL);

INSERT INTO devices (id, device_kind_id, motherboard_id, inventory_id, address, mac, canonical_name) VALUES
(1, 1, 1, 1, 'Bogus 00:01', '54:C0:AA:BB:01:01', 'omfc');

quit
EOF
