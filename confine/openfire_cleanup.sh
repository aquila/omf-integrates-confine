mysql -uopenfire -popenfire << EOF
use openfire;
truncate ofPubsubItem;
truncate ofPresence;
truncate ofPubsubSubscription;
truncate ofPubsubNode;
truncate ofPubsubAffiliation;
delete from ofUser where username not like 'aggmgr%' and username != 'admin';

INSERT INTO ofPubsubNode (serviceID, nodeID, leaf, creationDate, modificationDate, parent, deliverPayloads, maxPayloadSize, persistItems, maxItems, notifyConfigChanges, notifyDelete, notifyRetract, presenceBased, sendItemSubscribe, publisherModel, subscriptionEnabled, configSubscription, accessModel, payloadType, bodyXSLT, dataformXSLT, creator, description, language, name, replyPolicy, associationPolicy, maxLeafNodes) VALUES
('pubsub', '', 0, '001359658456502', '001359658456502', NULL, 0, 0, 0, 0, 1, 1, 1, 0, 0, 'publishers', 1, 0, 'open', '', '', '', 'confine-test1', '', 'English', '', NULL, 'all', -1),
('pubsub', '/OMF_5.4', 1, '001359658523315', '001359658523316', '', 1, 5120, 1, 1, 1, 1, 0, 0, 1, 'open', 1, 0, 'open', '', '', '', 'aggmgr@confine-test1/c7ac377', '', 'English', '/OMF_5.4', NULL, NULL, 0),
('pubsub', '/OMF_5.4/default_slice', 1, '001359658942532', '001359658942533', '', 1, 5120, 1, 1, 1, 1, 0, 0, 1, 'open', 1, 0, 'open', '', '', '', 'aggmgr@confine-test1/df839e7d', '', 'English', '/OMF_5.4/default_slice', 'owner', NULL, 0),
('pubsub', '/OMF_5.4/default_slice/resources', 1, '001370512746292', '001370512746293', '', 1, 5120, 1, 1, 1, 1, 0, 0, 1, 'open', 1, 0, 'open', '', '', '', 'aggmgr@confine-test1/f5117518', '', 'English', 'confine-test1', 'owner', NULL, 0),
('pubsub', '/OMF_5.4/pxe_slice/resources', 1, '001359658787099', '001359658787099', '', 1, 5120, 1, 1, 1, 1, 0, 0, 1, 'open', 1, 0, 'open', '', '', '', 'aggmgr@confine-test1/3e402d1c', '', 'English', 'confine-test1', 'owner', NULL, 0),
('pubsub', '/OMF_5.4/system', 1, '001359658523356', '001359658523357', '', 1, 5120, 1, 1, 1, 1, 0, 0, 1, 'open', 1, 0, 'open', '', '', '', 'aggmgr@confine-test1/c7ac377', '', 'English', '/OMF_5.4/system', NULL, NULL, 0);

INSERT INTO ofPubsubAffiliation (serviceID, nodeID, jid, affiliation) VALUES
('pubsub', '', 'confine-test1', 'owner'),
('pubsub', '/OMF_5.4', 'aggmgr@confine-test1', 'owner'),
('pubsub', '/OMF_5.4/default_slice', 'aggmgr@confine-test1', 'owner'),
('pubsub', '/OMF_5.4/pxe_slice/resources', 'aggmgr@confine-test1', 'owner'),
('pubsub', '/OMF_5.4/system', 'aggmgr@confine-test1', 'owner');
quit
EOF
