CREATE SCHEMA web;

CREATE TABLE web.subroutine (
	id serial4 NOT NULL,
	name VARCHAR(200) NOT NULL,
	duration_millis INTEGER,
	context_id VARCHAR(120),
	created_at timestamp DEFAULT now() NOT NULL,
	CONSTRAINT subroutine_pk PRIMARY KEY (id));


CREATE TABLE web.request (
	id serial4 NOT NULL,
	resource varchar(100) NOT NULL,
	queries varchar(200) NULL,
	"method" varchar(10) NOT NULL,
	duration_millis int4 NOT NULL,
	context_id varchar(120) NULL,
	created_at timestamp DEFAULT now() NOT NULL,
	status_code int4 DEFAULT 200 NULL,
	response_body text DEFAULT ''::text NULL,
	CONSTRAINT request_pk PRIMARY KEY (id));

CREATE INDEX subroutine_context_id_idx 
	ON web.subroutine (context_id);

CREATE INDEX request_created_at_idx 
	ON web.request (created_at);

CREATE INDEX request_context_id_idx 
	ON web.request (context_id);
