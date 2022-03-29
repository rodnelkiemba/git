#ifndef PROTOCOL_CAPS_H
#define PROTOCOL_CAPS_H

struct repository;
struct packet_reader;
int cap_object_info(struct repository *r, struct packet_reader *request);

/*
 * Advertises object-info capability if "objectinfo.advertise" is either
 * set to true or not set
 */
int object_info_advertise(struct repository *r, struct strbuf *value);

#endif /* PROTOCOL_CAPS_H */
