#!/bin/sh

test_description='test git fetch object-info version 2'

TEST_NO_CREATE_REPO=1

GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME=main
export GIT_TEST_DEFAULT_INITIAL_BRANCH_NAME

. ./test-lib.sh

# Test fetch object-info with 'git://' transport

. "$TEST_DIRECTORY"/lib-git-daemon.sh
start_git_daemon --export-all --enable=receive-pack
daemon_parent=$GIT_DAEMON_DOCUMENT_ROOT_PATH/parent


test_expect_success 'create repo to be served by git-daemon' '
	git init "$daemon_parent" &&
	test_commit -C "$daemon_parent" message1 a.txt
'

test_expect_success 'fetch object-info with git:// using protocol v2' '
	(
		cd "$daemon_parent" &&
		object_id=$(git rev-parse message1:a.txt) &&
		length=$(wc -c <a.txt) &&

		printf "%s %d\n" "$object_id" "$length" >expect &&
		git -c protocol.version=2 fetch --object-info=size "$GIT_DAEMON_URL/parent" "$object_id" >actual &&
		test_cmp expect actual
	)
'
stop_git_daemon

# Test protocol v2 with 'http://' transport

. "$TEST_DIRECTORY"/lib-httpd.sh
start_httpd

test_expect_success 'create repo to be served by http:// transport' '
	git init "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
	git -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" config http.receivepack true &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" message1 a.txt &&
	test_commit -C "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" message2 b.txt
'

test_expect_success 'fetch object-info with http:// using protocol v2' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
		object_id=$(git rev-parse message1:a.txt) &&
		length=$(wc -c <a.txt) &&

		printf "%s %d\n" "$object_id" "$length" >expect &&
		git -c protocol.version=2 fetch --object-info=size "$HTTPD_URL/smart/http_parent" "$object_id" >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'fetch object-info for multiple objects' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
		object_id1=$(git rev-parse message1:a.txt) &&
		object_id2=$(git rev-parse message2:b.txt) &&
		length1=$(wc -c <a.txt) &&
		length2=$(wc -c <b.txt) &&

		printf "%s %d\n" "$object_id1" "$length1" >expect &&
		printf "%s %d\n" "$object_id2" "$length2" >>expect &&
		git -c protocol.version=2 fetch --object-info=size "$HTTPD_URL/smart/http_parent" "$object_id1" "$object_id2" >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'fetch object-info fallbacks to standard fetch if object-info is not supported by the server' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
		object_id=$(git rev-parse message1:a.txt) &&
		length=$(wc -c <a.txt) &&

		printf "%s %d\n" "$object_id" "$length" >expect &&
		git config objectinfo.advertise false &&
		git -c protocol.version=2 fetch --object-info=size "$HTTPD_URL/smart/http_parent" "$object_id" >actual &&
		test_cmp expect actual
	)
'

test_expect_success 'fetch object-info fails on server with legacy protocol' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
		object_id=$(git rev-parse message1:a.txt) &&
		test_must_fail git -c protocol.version=0 fetch --object-info=size "$HTTPD_URL/smart/http_parent" "$object_id" 2>err &&
		test_i18ngrep "object-info requires protocol v2" err
	)
'

test_expect_success 'fetch object-info fails on malformed OID' '
	(
		cd "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" &&
		malformed_object_id="this_id_is_not_valid" &&
		test_must_fail git -c protocol.version=2 fetch --object-info=size "$HTTPD_URL/smart/http_parent" "$malformed_object_id" 2>err &&
		test_i18ngrep "malformed object id '$malformed_object_id'" err
	)
'

test_expect_success 'fetch object-info fails on missing OID' '
	git clone "$HTTPD_DOCUMENT_ROOT_PATH/http_parent" missing_oid_repo &&
	test_commit -C missing_oid_repo message3 c.txt &&
	(
		cd missing_oid_repo &&
		object_id=$(git rev-parse message3:c.txt) &&
		test_must_fail env GIT_TRACE_PACKET=1 git -c protocol.version=2 fetch --object-info=size "$HTTPD_URL/smart/http_parent" "$object_id" 2>err &&
		test_i18ngrep "fatal: remote error: upload-pack: not our ref $object_id" err
	)
'

# Test fetch object-info with 'file://' transport

test_expect_success 'create repo to be served by file:// transport' '
	git init server &&
	test_commit -C server message1 a.txt &&
	git -C server config protocol.version 2
'

test_expect_success 'fetch object-info with file:// using protocol v2' '
	(
		cd server &&
		object_id=$(git rev-parse message1:a.txt) &&
		length=$(wc -c <a.txt) &&

		printf "%s %d\n" "$object_id" "$length" >expect &&
		git -c protocol.version=2 fetch --object-info=size "file://$(pwd)" "$object_id" >actual &&
		test_cmp expect actual
	)
'

test_done
