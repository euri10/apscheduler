DO
$$
    BEGIN
        PERFORM 'coalescepolicy'::regtype;
    EXCEPTION
        WHEN undefined_object THEN CREATE TYPE coalescepolicy AS ENUM ( 'earliest', 'latest', 'all' );
    END
$$;

DO
$$
    BEGIN
        PERFORM 'joboutcome'::regtype;
    EXCEPTION
        WHEN undefined_object THEN CREATE TYPE joboutcome AS ENUM ( 'success', 'error', 'missed_start_deadline', 'cancelled' );

    END
$$;


CREATE TABLE if not exists job_results
(
    job_id       uuid                     NOT NULL,
    outcome      joboutcome               NOT NULL,
    finished_at  timestamp with time zone,
    expires_at   timestamp with time zone NOT NULL,
    exception    bytea,
    return_value bytea
);

CREATE TABLE if not exists jobs
(
    id                     uuid                     NOT NULL,
    task_id                character varying(500)   NOT NULL,
    args                   bytea                    NOT NULL,
    kwargs                 bytea                    NOT NULL,
    schedule_id            character varying(500),
    scheduled_fire_time    timestamp with time zone,
    jitter                 interval(6),
    start_deadline         timestamp with time zone,
    result_expiration_time interval(6),
    tags                   character varying[]      NOT NULL,
    created_at             timestamp with time zone NOT NULL,
    started_at             timestamp with time zone,
    acquired_by            character varying(500),
    acquired_until         timestamp with time zone
);

CREATE TABLE if not exists metadata
(
    schema_version integer NOT NULL
);

CREATE TABLE if not exists schedules
(
    id                 character varying(500) NOT NULL,
    task_id            character varying(500) NOT NULL,
    trigger            bytea,
    args               bytea,
    kwargs             bytea,
    "coalesce"         coalescepolicy         NOT NULL,
    misfire_grace_time interval(6),
    max_jitter         interval(6),
    tags               character varying[]    NOT NULL,
    next_fire_time     timestamp with time zone,
    last_fire_time     timestamp with time zone,
    acquired_by        character varying(500),
    acquired_until     timestamp with time zone
);

CREATE TABLE if not exists tasks
(
    id                 character varying(500) NOT NULL,
    func               character varying(500) NOT NULL,
    executor           character varying(500) NOT NULL,
    state              bytea,
    max_running_jobs   integer,
    misfire_grace_time interval(6),
    running_jobs       integer DEFAULT 0      NOT NULL
);

DO $$
BEGIN
    IF NOT exists(select FROM pg_constraint WHERE conname = 'job_results_pkey') THEN
        ALTER TABLE ONLY job_results
            ADD CONSTRAINT job_results_pkey PRIMARY KEY (job_id);
    END IF;
    IF NOT exists(select FROM pg_constraint WHERE conname = 'jobs_pkey') THEN
        ALTER TABLE ONLY jobs
            ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);
    END IF;
    IF NOT exists(select FROM pg_constraint WHERE conname = 'schedules_pkey') THEN
        ALTER TABLE ONLY schedules
            ADD CONSTRAINT schedules_pkey PRIMARY KEY (id);
    END IF;
    IF NOT exists(select FROM pg_constraint WHERE conname = 'tasks_pkey') THEN
        ALTER TABLE ONLY tasks
            ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);
    END IF;
END$$;


CREATE INDEX if not exists ix_job_results_expires_at ON job_results USING btree (expires_at);

CREATE INDEX if not exists ix_job_results_finished_at ON job_results USING btree (finished_at);

CREATE INDEX if not exists ix_jobs_task_id ON jobs USING btree (task_id);

CREATE INDEX if not exists ix_schedules_next_fire_time ON schedules USING btree (next_fire_time);

CREATE INDEX if not exists ix_schedules_task_id ON schedules USING btree (task_id);
