--
-- PostgreSQL database dump
--

-- Dumped from database version 15.12 (Postgres.app)
-- Dumped by pg_dump version 15.12 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ad_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_categories (
    id integer NOT NULL,
    ad_category_name character varying(256) DEFAULT ''::character varying NOT NULL
);


--
-- Name: ad_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ad_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ad_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ad_categories_id_seq OWNED BY public.ad_categories.id;


--
-- Name: ad_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_events (
    id integer NOT NULL,
    campaign_id integer,
    me_file_id integer,
    media_run_id integer,
    media_piece_id integer,
    media_piece_phase_id integer,
    target_id integer,
    target_band_id integer,
    offer_id integer,
    offer_bid_amt numeric(8,2),
    is_payable boolean,
    is_throttled boolean,
    is_demo boolean,
    is_offer_complete boolean DEFAULT false,
    offer_marketer_cost_amt numeric(8,2),
    event_marketer_cost_amt numeric(8,2),
    event_me_file_collect_amt numeric(8,2),
    referral_credit_id integer,
    recipient_id integer,
    event_recipient_split_pct integer,
    event_recipient_collect_amt numeric(8,2),
    event_sponster_collect_amt numeric(8,2),
    event_sponster_to_recipient_amt numeric(8,2),
    event_split_code character varying(255),
    ip_address character varying(255),
    url character varying(255),
    adget_id_string character varying(255),
    session_id_string character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    matching_tags_snapshot character varying
);


--
-- Name: ad_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ad_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ad_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ad_events_id_seq OWNED BY public.ad_events.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: bids; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bids (
    id integer NOT NULL,
    campaign_id integer,
    media_run_id integer,
    target_band_id integer,
    offer_amt numeric(10,2),
    marketer_cost_amt numeric(10,2),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: bids_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bids_id_seq OWNED BY public.bids.id;


--
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaigns (
    id integer NOT NULL,
    marketer_id integer,
    target_id integer,
    media_sequence_id integer,
    title character varying(255),
    description text,
    start_date timestamp without time zone,
    end_date timestamp without time zone,
    is_payable boolean,
    is_throttled boolean,
    is_demo boolean,
    deactivated_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: campaigns_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.campaigns_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: campaigns_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.campaigns_id_seq OWNED BY public.campaigns.id;


--
-- Name: catalogs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalogs (
    id bigint NOT NULL,
    creator_id bigint,
    name character varying(255),
    url character varying(255),
    type character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: catalogs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.catalogs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: catalogs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.catalogs_id_seq OWNED BY public.catalogs.id;


--
-- Name: content_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_groups (
    id bigint NOT NULL,
    catalog_id bigint,
    title text NOT NULL,
    description text,
    type character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: content_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_groups_id_seq OWNED BY public.content_groups.id;


--
-- Name: content_pieces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.content_pieces (
    id bigint NOT NULL,
    content_group_id bigint NOT NULL,
    title text NOT NULL,
    description text,
    content_type text NOT NULL,
    date_published date NOT NULL,
    length integer NOT NULL,
    preview_length integer NOT NULL,
    file_url text NOT NULL,
    preview_url text NOT NULL,
    price_default numeric(10,2) NOT NULL,
    type character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: content_pieces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_pieces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_pieces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_pieces_id_seq OWNED BY public.content_pieces.id;


--
-- Name: creators; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.creators (
    id bigint NOT NULL,
    name character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: creators_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.creators_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: creators_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.creators_id_seq OWNED BY public.creators.id;


--
-- Name: global_variables; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.global_variables (
    id integer NOT NULL,
    name character varying(64) DEFAULT ''::character varying NOT NULL,
    value text
);


--
-- Name: global_variables_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.global_variables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: global_variables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.global_variables_id_seq OWNED BY public.global_variables.id;


--
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_entries (
    id integer NOT NULL,
    amt numeric(8,2),
    description character varying(255),
    is_payable boolean,
    ledger_header_id integer,
    ad_event_id integer,
    transfer_event_id integer,
    payout_event_id integer,
    running_balance numeric(8,2),
    running_balance_payable numeric(8,2),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ledger_entries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ledger_entries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ledger_entries_id_seq OWNED BY public.ledger_entries.id;


--
-- Name: ledger_headers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_headers (
    id integer NOT NULL,
    description character varying(255),
    balance numeric(10,2),
    balance_payable numeric(10,2),
    me_file_id integer,
    campaign_id integer,
    recipient_id integer,
    marketer_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: ledger_headers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ledger_headers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ledger_headers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ledger_headers_id_seq OWNED BY public.ledger_headers.id;


--
-- Name: marketer_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.marketer_users (
    id integer NOT NULL,
    user_id integer,
    marketer_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: marketer_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.marketer_users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: marketer_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.marketer_users_id_seq OWNED BY public.marketer_users.id;


--
-- Name: marketers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.marketers (
    id integer NOT NULL,
    business_name character varying(255),
    business_url character varying(255),
    contact_first_name character varying(255),
    contact_last_name character varying(255),
    contact_number character varying(255),
    contact_email character varying(255),
    sic_code character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: marketers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.marketers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: marketers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.marketers_id_seq OWNED BY public.marketers.id;


--
-- Name: me_file_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.me_file_tags (
    id integer NOT NULL,
    me_file_id integer NOT NULL,
    trait_id integer NOT NULL,
    tag_value character varying(256),
    expiration_date timestamp without time zone NOT NULL,
    modified_date timestamp without time zone NOT NULL,
    modified_by integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by integer NOT NULL,
    customized_hash text
);


--
-- Name: me_file_tags_MeFileTagId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."me_file_tags_MeFileTagId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: me_file_tags_MeFileTagId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."me_file_tags_MeFileTagId_seq" OWNED BY public.me_file_tags.id;


--
-- Name: me_file_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.me_file_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: me_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.me_files (
    id integer NOT NULL,
    user_id integer,
    display_name character varying(75),
    date_of_birth date,
    ledger_header_id integer,
    sponster_token character varying(50),
    split_amount integer DEFAULT 50,
    referral_id integer,
    referral_code character varying(255),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: me_files_MeFileId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."me_files_MeFileId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: me_files_MeFileId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."me_files_MeFileId_seq" OWNED BY public.me_files.id;


--
-- Name: me_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.me_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_piece_phases; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_piece_phases (
    id integer NOT NULL,
    media_piece_type_id integer,
    phase integer,
    name character varying(255),
    "desc" character varying(255),
    is_final_phase boolean DEFAULT false,
    pay_to_me_file_fixed numeric(8,2),
    pay_to_me_file_percent numeric(8,2),
    pay_to_sponster_fixed numeric(8,2),
    pay_to_sponster_percent numeric(8,2),
    pay_to_recipient_from_sponster_fixed numeric(8,2),
    pay_to_recipient_from_sponster_percent numeric(8,2),
    pay_to_recipient_from_me_file_fixed numeric(8,2),
    pay_to_recipient_from_me_file_percent numeric(8,2),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: media_piece_phases_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_piece_phases_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_piece_phases_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_piece_phases_id_seq OWNED BY public.media_piece_phases.id;


--
-- Name: media_piece_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_piece_types (
    id integer NOT NULL,
    name character varying(255),
    "desc" character varying(255),
    ad_phase_count_to_complete integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: media_piece_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_piece_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_piece_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_piece_types_id_seq OWNED BY public.media_piece_types.id;


--
-- Name: media_pieces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_pieces (
    id integer NOT NULL,
    marketer_id integer NOT NULL,
    ad_category_id integer NOT NULL,
    media_piece_type_id smallint NOT NULL,
    title character varying(256),
    display_url character varying(256),
    body_copy character varying(1028),
    resource_url_old character varying(512),
    resource_url character varying(512),
    resource_file_name character varying(255),
    resource_content_type character varying(255),
    resource_file_size integer,
    resource_updated_at timestamp without time zone,
    duration integer,
    jump_url character varying(512),
    active boolean NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    banner_image character varying(255)
);


--
-- Name: media_pieces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_pieces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_pieces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_pieces_id_seq OWNED BY public.media_pieces.id;


--
-- Name: media_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_runs (
    id integer NOT NULL,
    marketer_id integer,
    media_sequence_id integer,
    media_piece_id integer,
    sequence_start_phase integer,
    sequence_end_phase integer,
    frequency integer,
    frequency_buffer_hours integer,
    maximum_banner_count integer,
    banner_retry_buffer_hours integer,
    is_active boolean,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: media_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_runs_id_seq OWNED BY public.media_runs.id;


--
-- Name: media_sequences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_sequences (
    id integer NOT NULL,
    marketer_id integer,
    title character varying(255),
    description text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: media_sequences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.media_sequences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: media_sequences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.media_sequences_id_seq OWNED BY public.media_sequences.id;


--
-- Name: mobile_phones; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mobile_phones (
    id integer NOT NULL,
    me_file_id integer NOT NULL,
    mobile_number character varying(11) DEFAULT ''::character varying NOT NULL,
    activation_code character varying(255) DEFAULT ''::character varying,
    activation_code_sent_at timestamp without time zone,
    activated_at timestamp without time zone,
    deactivated_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: mobile_phones_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mobile_phones_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mobile_phones_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mobile_phones_id_seq OWNED BY public.mobile_phones.id;


--
-- Name: mobile_registration_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mobile_registration_requests (
    id bigint NOT NULL,
    mobile_number character varying NOT NULL,
    referral_code character varying,
    validation_code character varying NOT NULL,
    validation_api_response character varying,
    validation_code_sent timestamp without time zone,
    validation_success_at timestamp without time zone,
    gender character varying,
    birthdate date,
    home_zip_entered character varying,
    home_zip_trait_id character varying,
    ip_address character varying,
    browser character varying,
    device character varying,
    platform character varying,
    registration_success_at timestamp without time zone,
    me_file_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: mobile_registration_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mobile_registration_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mobile_registration_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mobile_registration_requests_id_seq OWNED BY public.mobile_registration_requests.id;


--
-- Name: oauth_access_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_access_grants (
    id integer NOT NULL,
    resource_owner_id integer NOT NULL,
    application_id integer NOT NULL,
    token character varying(255) NOT NULL,
    expires_in integer NOT NULL,
    redirect_uri text NOT NULL,
    created_at timestamp without time zone NOT NULL,
    revoked_at timestamp without time zone,
    scopes character varying(255)
);


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_access_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_access_grants_id_seq OWNED BY public.oauth_access_grants.id;


--
-- Name: oauth_access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_access_tokens (
    id integer NOT NULL,
    resource_owner_id integer,
    application_id integer,
    token character varying(255) NOT NULL,
    refresh_token character varying(255),
    expires_in integer,
    revoked_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL,
    scopes character varying(255)
);


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_access_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_access_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_access_tokens_id_seq OWNED BY public.oauth_access_tokens.id;


--
-- Name: oauth_applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oauth_applications (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    uid character varying(255) NOT NULL,
    secret character varying(255) NOT NULL,
    redirect_uri text NOT NULL,
    created_at timestamp without time zone,
    updated_at timestamp without time zone,
    scopes character varying(255) DEFAULT ''::character varying NOT NULL
);


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.oauth_applications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: oauth_applications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.oauth_applications_id_seq OWNED BY public.oauth_applications.id;


--
-- Name: offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offers (
    id integer NOT NULL,
    campaign_id integer NOT NULL,
    me_file_id integer NOT NULL,
    media_run_id integer NOT NULL,
    media_piece_id integer NOT NULL,
    ad_phase_count_to_complete smallint NOT NULL,
    target_band_id integer NOT NULL,
    offer_amt numeric(10,2) NOT NULL,
    marketer_cost_amt numeric(10,2) NOT NULL,
    pending_until timestamp without time zone,
    is_payable boolean DEFAULT false NOT NULL,
    is_throttled boolean DEFAULT false NOT NULL,
    is_demo boolean DEFAULT false NOT NULL,
    is_current boolean DEFAULT false NOT NULL,
    is_jobbed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    matching_tags_snapshot character varying
);


--
-- Name: offers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.offers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: offers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.offers_id_seq OWNED BY public.offers.id;


--
-- Name: recipient_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipient_types (
    id integer NOT NULL,
    type_name character varying(255)
);


--
-- Name: recipient_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recipient_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recipient_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recipient_types_id_seq OWNED BY public.recipient_types.id;


--
-- Name: recipients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.recipients (
    id integer NOT NULL,
    split_code character varying(255) DEFAULT ''::character varying,
    user_id integer NOT NULL,
    name character varying(255),
    description text,
    message text,
    target_amount numeric(10,2),
    site_url character varying(255),
    graphic_url character varying(255),
    recipient_type_id integer,
    contact_email character varying(255),
    approval_date timestamp without time zone,
    approved_by_user_id integer,
    updated_at timestamp without time zone,
    created_at timestamp without time zone,
    referral_code character varying(255)
);


--
-- Name: recipients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.recipients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: recipients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.recipients_id_seq OWNED BY public.recipients.id;


--
-- Name: referral_clicks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral_clicks (
    id integer NOT NULL,
    referral_id integer,
    referral_credit_id integer,
    ad_event_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: referral_clicks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.referral_clicks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: referral_clicks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.referral_clicks_id_seq OWNED BY public.referral_clicks.id;


--
-- Name: referral_credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral_credits (
    id integer NOT NULL,
    ledger_entry_id integer,
    credit_amt integer,
    me_file_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: referral_credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.referral_credits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: referral_credits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.referral_credits_id_seq OWNED BY public.referral_credits.id;


--
-- Name: referrals; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referrals (
    id integer NOT NULL,
    me_file_id integer,
    recipient_id integer,
    referred_me_file_id integer NOT NULL,
    is_fulfilled boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: referrals_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.referrals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: referrals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.referrals_id_seq OWNED BY public.referrals.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: sponster_widget_serve_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sponster_widget_serve_logs (
    id bigint NOT NULL,
    user_id bigint,
    recipient_id bigint,
    username character varying,
    user_email character varying,
    offers_count integer,
    offers_amount numeric,
    recipient_split_code character varying,
    recipient_referral_code character varying,
    ip_address character varying,
    host_page_url text,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    browser character varying,
    device text,
    platform character varying
);


--
-- Name: sponster_widget_serve_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sponster_widget_serve_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sponster_widget_serve_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sponster_widget_serve_logs_id_seq OWNED BY public.sponster_widget_serve_logs.id;


--
-- Name: survey_answers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_answers (
    id integer NOT NULL,
    text character varying(4096),
    survey_question_id integer,
    trait_id integer,
    display_order integer,
    next_survey_question_id integer,
    modified_date timestamp without time zone NOT NULL,
    modified_by integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by integer NOT NULL
);


--
-- Name: survey_answers_SurveyAnswerId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."survey_answers_SurveyAnswerId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_answers_SurveyAnswerId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."survey_answers_SurveyAnswerId_seq" OWNED BY public.survey_answers.id;


--
-- Name: survey_answers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_answers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_categories (
    id integer NOT NULL,
    survey_category_name character varying(256) NOT NULL,
    display_order integer,
    modified_date timestamp without time zone NOT NULL,
    modified_by_id integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by_id integer NOT NULL
);


--
-- Name: survey_categories_SurveyCategoryId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."survey_categories_SurveyCategoryId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_categories_SurveyCategoryId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."survey_categories_SurveyCategoryId_seq" OWNED BY public.survey_categories.id;


--
-- Name: survey_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_question_surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_question_surveys (
    id integer NOT NULL,
    survey_question_id integer NOT NULL,
    survey_id integer NOT NULL,
    display_order integer,
    created_at timestamp without time zone,
    updated_at timestamp without time zone
);


--
-- Name: survey_question_surveys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_question_surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_question_surveys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_question_surveys_id_seq OWNED BY public.survey_question_surveys.id;


--
-- Name: survey_questions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_questions (
    id integer NOT NULL,
    text character varying(4096),
    trait_id integer,
    modified_date timestamp without time zone NOT NULL,
    modified_by integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by integer NOT NULL,
    active bytea NOT NULL,
    display_order integer
);


--
-- Name: survey_questions_SurveyQuestionId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."survey_questions_SurveyQuestionId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: survey_questions_SurveyQuestionId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."survey_questions_SurveyQuestionId_seq" OWNED BY public.survey_questions.id;


--
-- Name: survey_questions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.survey_questions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.surveys (
    id integer NOT NULL,
    name character varying(512) NOT NULL,
    survey_category_id integer,
    updated_at timestamp without time zone NOT NULL,
    updated_by_id integer NOT NULL,
    created_at timestamp without time zone NOT NULL,
    created_by_id integer NOT NULL,
    display_order integer,
    active boolean DEFAULT false NOT NULL
);


--
-- Name: surveys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: surveys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.surveys_id_seq OWNED BY public.surveys.id;


--
-- Name: target_band_trait_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.target_band_trait_groups (
    id integer NOT NULL,
    target_band_id integer,
    trait_group_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: target_band_trait_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.target_band_trait_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: target_band_trait_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.target_band_trait_groups_id_seq OWNED BY public.target_band_trait_groups.id;


--
-- Name: target_bands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.target_bands (
    id integer NOT NULL,
    target_id integer,
    title character varying(255),
    description character varying(255),
    is_bullseye character varying DEFAULT '0'::character varying NOT NULL,
    user_created_by integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: target_bands_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.target_bands_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: target_bands_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.target_bands_id_seq OWNED BY public.target_bands.id;


--
-- Name: target_populations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.target_populations (
    id integer NOT NULL,
    target_band_id integer,
    me_file_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: target_populations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.target_populations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: target_populations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.target_populations_id_seq OWNED BY public.target_populations.id;


--
-- Name: targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.targets (
    id integer NOT NULL,
    marketer_id integer,
    title character varying(255),
    description character varying(255),
    user_created_by integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: targets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.targets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: targets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.targets_id_seq OWNED BY public.targets.id;


--
-- Name: tiqit_classes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tiqit_classes (
    id bigint NOT NULL,
    catalog_id bigint,
    content_group_id bigint,
    content_piece_id bigint,
    name character varying(255) NOT NULL,
    duration_hours integer,
    price numeric(10,2) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tiqit_classes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tiqit_classes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tiqit_classes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tiqit_classes_id_seq OWNED BY public.tiqit_classes.id;


--
-- Name: trait_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trait_categories (
    id integer NOT NULL,
    trait_category_name character varying(256) NOT NULL,
    display_order integer,
    modified_date timestamp without time zone NOT NULL,
    modified_by integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by integer NOT NULL
);


--
-- Name: trait_categories_TraitCategoryId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."trait_categories_TraitCategoryId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trait_categories_TraitCategoryId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."trait_categories_TraitCategoryId_seq" OWNED BY public.trait_categories.id;


--
-- Name: trait_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trait_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trait_group_traits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trait_group_traits (
    id integer NOT NULL,
    trait_group_id integer,
    trait_id integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: trait_group_traits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trait_group_traits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trait_group_traits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trait_group_traits_id_seq OWNED BY public.trait_group_traits.id;


--
-- Name: trait_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trait_groups (
    id integer NOT NULL,
    title character varying(255),
    description character varying(255),
    parent_trait_id integer,
    marketer_id integer,
    user_created_by integer,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    deactivated_at timestamp without time zone
);


--
-- Name: trait_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trait_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trait_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trait_groups_id_seq OWNED BY public.trait_groups.id;


--
-- Name: trait_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trait_values (
    id integer NOT NULL,
    trait_name character varying(256) NOT NULL,
    input_type character varying(30) NOT NULL,
    display_order integer NOT NULL,
    parent_trait_id integer NOT NULL,
    is_campaign_only boolean NOT NULL,
    is_numeric boolean,
    modified_date timestamp without time zone NOT NULL,
    modified_by integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by integer NOT NULL,
    trait_category_id integer,
    immutable boolean NOT NULL,
    max_length integer,
    max_selected integer,
    is_date boolean,
    is_taggable boolean NOT NULL,
    active boolean NOT NULL
);


--
-- Name: traits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traits (
    id integer NOT NULL,
    trait_name character varying(256) NOT NULL,
    input_type character varying(30) NOT NULL,
    display_order integer NOT NULL,
    parent_trait_id integer,
    is_campaign_only boolean DEFAULT false NOT NULL,
    is_numeric boolean DEFAULT false,
    modified_date timestamp without time zone NOT NULL,
    modified_by integer NOT NULL,
    added_date timestamp without time zone NOT NULL,
    added_by integer NOT NULL,
    trait_category_id integer,
    immutable boolean DEFAULT false NOT NULL,
    max_length integer,
    max_selected integer,
    is_date boolean DEFAULT false,
    is_taggable boolean NOT NULL,
    active boolean NOT NULL
);


--
-- Name: traits_TraitId_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."traits_TraitId_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traits_TraitId_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."traits_TraitId_seq" OWNED BY public.traits.id;


--
-- Name: traits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_prefs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_prefs (
    id bigint NOT NULL,
    sponster_email_alerts boolean,
    sponster_text_alerts boolean,
    sponster_browser_alerts boolean,
    sponster_push_notifications boolean,
    user_id bigint,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: user_prefs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_prefs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_prefs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_prefs_id_seq OWNED BY public.user_prefs.id;


--
-- Name: user_proxies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_proxies (
    id bigint NOT NULL,
    active boolean,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    true_user_id bigint,
    proxy_user_id bigint
);


--
-- Name: user_proxies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_proxies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_proxies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_proxies_id_seq OWNED BY public.user_proxies.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp without time zone,
    remember_created_at timestamp without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp without time zone,
    last_sign_in_at timestamp without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    confirmation_token character varying(255),
    confirmed_at timestamp without time zone,
    confirmation_sent_at timestamp without time zone,
    unconfirmed_email character varying(255),
    failed_attempts integer DEFAULT 0,
    unlock_token character varying(255),
    locked_at timestamp without time zone,
    authentication_token character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL,
    referrer_code character varying(255),
    role character varying,
    passage_id character varying,
    mobile_number character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: worker_job_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.worker_job_logs (
    id integer NOT NULL,
    job_name character varying(255),
    job_key character varying(255),
    job_value character varying(255),
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
);


--
-- Name: worker_job_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.worker_job_logs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: worker_job_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.worker_job_logs_id_seq OWNED BY public.worker_job_logs.id;


--
-- Name: ad_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_categories ALTER COLUMN id SET DEFAULT nextval('public.ad_categories_id_seq'::regclass);


--
-- Name: ad_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_events ALTER COLUMN id SET DEFAULT nextval('public.ad_events_id_seq'::regclass);


--
-- Name: bids id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bids ALTER COLUMN id SET DEFAULT nextval('public.bids_id_seq'::regclass);


--
-- Name: campaigns id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns ALTER COLUMN id SET DEFAULT nextval('public.campaigns_id_seq'::regclass);


--
-- Name: catalogs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogs ALTER COLUMN id SET DEFAULT nextval('public.catalogs_id_seq'::regclass);


--
-- Name: content_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_groups ALTER COLUMN id SET DEFAULT nextval('public.content_groups_id_seq'::regclass);


--
-- Name: content_pieces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_pieces ALTER COLUMN id SET DEFAULT nextval('public.content_pieces_id_seq'::regclass);


--
-- Name: creators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators ALTER COLUMN id SET DEFAULT nextval('public.creators_id_seq'::regclass);


--
-- Name: global_variables id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_variables ALTER COLUMN id SET DEFAULT nextval('public.global_variables_id_seq'::regclass);


--
-- Name: ledger_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries ALTER COLUMN id SET DEFAULT nextval('public.ledger_entries_id_seq'::regclass);


--
-- Name: ledger_headers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_headers ALTER COLUMN id SET DEFAULT nextval('public.ledger_headers_id_seq'::regclass);


--
-- Name: marketer_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketer_users ALTER COLUMN id SET DEFAULT nextval('public.marketer_users_id_seq'::regclass);


--
-- Name: marketers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketers ALTER COLUMN id SET DEFAULT nextval('public.marketers_id_seq'::regclass);


--
-- Name: me_file_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.me_file_tags ALTER COLUMN id SET DEFAULT nextval('public."me_file_tags_MeFileTagId_seq"'::regclass);


--
-- Name: me_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.me_files ALTER COLUMN id SET DEFAULT nextval('public."me_files_MeFileId_seq"'::regclass);


--
-- Name: media_piece_phases id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_piece_phases ALTER COLUMN id SET DEFAULT nextval('public.media_piece_phases_id_seq'::regclass);


--
-- Name: media_piece_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_piece_types ALTER COLUMN id SET DEFAULT nextval('public.media_piece_types_id_seq'::regclass);


--
-- Name: media_pieces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_pieces ALTER COLUMN id SET DEFAULT nextval('public.media_pieces_id_seq'::regclass);


--
-- Name: media_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_runs ALTER COLUMN id SET DEFAULT nextval('public.media_runs_id_seq'::regclass);


--
-- Name: media_sequences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_sequences ALTER COLUMN id SET DEFAULT nextval('public.media_sequences_id_seq'::regclass);


--
-- Name: mobile_phones id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_phones ALTER COLUMN id SET DEFAULT nextval('public.mobile_phones_id_seq'::regclass);


--
-- Name: mobile_registration_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_registration_requests ALTER COLUMN id SET DEFAULT nextval('public.mobile_registration_requests_id_seq'::regclass);


--
-- Name: oauth_access_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_grants_id_seq'::regclass);


--
-- Name: oauth_access_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens ALTER COLUMN id SET DEFAULT nextval('public.oauth_access_tokens_id_seq'::regclass);


--
-- Name: oauth_applications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_applications ALTER COLUMN id SET DEFAULT nextval('public.oauth_applications_id_seq'::regclass);


--
-- Name: offers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers ALTER COLUMN id SET DEFAULT nextval('public.offers_id_seq'::regclass);


--
-- Name: recipient_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_types ALTER COLUMN id SET DEFAULT nextval('public.recipient_types_id_seq'::regclass);


--
-- Name: recipients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipients ALTER COLUMN id SET DEFAULT nextval('public.recipients_id_seq'::regclass);


--
-- Name: referral_clicks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_clicks ALTER COLUMN id SET DEFAULT nextval('public.referral_clicks_id_seq'::regclass);


--
-- Name: referral_credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_credits ALTER COLUMN id SET DEFAULT nextval('public.referral_credits_id_seq'::regclass);


--
-- Name: referrals id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals ALTER COLUMN id SET DEFAULT nextval('public.referrals_id_seq'::regclass);


--
-- Name: sponster_widget_serve_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponster_widget_serve_logs ALTER COLUMN id SET DEFAULT nextval('public.sponster_widget_serve_logs_id_seq'::regclass);


--
-- Name: survey_answers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_answers ALTER COLUMN id SET DEFAULT nextval('public."survey_answers_SurveyAnswerId_seq"'::regclass);


--
-- Name: survey_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_categories ALTER COLUMN id SET DEFAULT nextval('public."survey_categories_SurveyCategoryId_seq"'::regclass);


--
-- Name: survey_question_surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_question_surveys ALTER COLUMN id SET DEFAULT nextval('public.survey_question_surveys_id_seq'::regclass);


--
-- Name: survey_questions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_questions ALTER COLUMN id SET DEFAULT nextval('public."survey_questions_SurveyQuestionId_seq"'::regclass);


--
-- Name: surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys ALTER COLUMN id SET DEFAULT nextval('public.surveys_id_seq'::regclass);


--
-- Name: target_band_trait_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_band_trait_groups ALTER COLUMN id SET DEFAULT nextval('public.target_band_trait_groups_id_seq'::regclass);


--
-- Name: target_bands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands ALTER COLUMN id SET DEFAULT nextval('public.target_bands_id_seq'::regclass);


--
-- Name: target_populations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_populations ALTER COLUMN id SET DEFAULT nextval('public.target_populations_id_seq'::regclass);


--
-- Name: targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets ALTER COLUMN id SET DEFAULT nextval('public.targets_id_seq'::regclass);


--
-- Name: tiqit_classes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_classes ALTER COLUMN id SET DEFAULT nextval('public.tiqit_classes_id_seq'::regclass);


--
-- Name: trait_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_categories ALTER COLUMN id SET DEFAULT nextval('public."trait_categories_TraitCategoryId_seq"'::regclass);


--
-- Name: trait_group_traits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_group_traits ALTER COLUMN id SET DEFAULT nextval('public.trait_group_traits_id_seq'::regclass);


--
-- Name: trait_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_groups ALTER COLUMN id SET DEFAULT nextval('public.trait_groups_id_seq'::regclass);


--
-- Name: traits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits ALTER COLUMN id SET DEFAULT nextval('public."traits_TraitId_seq"'::regclass);


--
-- Name: user_prefs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_prefs ALTER COLUMN id SET DEFAULT nextval('public.user_prefs_id_seq'::regclass);


--
-- Name: user_proxies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_proxies ALTER COLUMN id SET DEFAULT nextval('public.user_proxies_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: worker_job_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.worker_job_logs ALTER COLUMN id SET DEFAULT nextval('public.worker_job_logs_id_seq'::regclass);


--
-- Name: ad_categories ad_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_categories
    ADD CONSTRAINT ad_categories_pkey PRIMARY KEY (id);


--
-- Name: ad_events ad_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_events
    ADD CONSTRAINT ad_events_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: bids bids_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bids
    ADD CONSTRAINT bids_pkey PRIMARY KEY (id);


--
-- Name: campaigns campaigns_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_pkey PRIMARY KEY (id);


--
-- Name: catalogs catalogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogs
    ADD CONSTRAINT catalogs_pkey PRIMARY KEY (id);


--
-- Name: content_groups content_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_groups
    ADD CONSTRAINT content_groups_pkey PRIMARY KEY (id);


--
-- Name: content_pieces content_pieces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_pieces
    ADD CONSTRAINT content_pieces_pkey PRIMARY KEY (id);


--
-- Name: creators creators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators
    ADD CONSTRAINT creators_pkey PRIMARY KEY (id);


--
-- Name: global_variables global_variables_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.global_variables
    ADD CONSTRAINT global_variables_pkey PRIMARY KEY (id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: ledger_headers ledger_headers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_headers
    ADD CONSTRAINT ledger_headers_pkey PRIMARY KEY (id);


--
-- Name: marketer_users marketer_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketer_users
    ADD CONSTRAINT marketer_users_pkey PRIMARY KEY (id);


--
-- Name: marketers marketers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.marketers
    ADD CONSTRAINT marketers_pkey PRIMARY KEY (id);


--
-- Name: me_file_tags me_file_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.me_file_tags
    ADD CONSTRAINT me_file_tags_pkey PRIMARY KEY (id);


--
-- Name: me_files me_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.me_files
    ADD CONSTRAINT me_files_pkey PRIMARY KEY (id);


--
-- Name: media_piece_phases media_piece_phases_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_piece_phases
    ADD CONSTRAINT media_piece_phases_pkey PRIMARY KEY (id);


--
-- Name: media_piece_types media_piece_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_piece_types
    ADD CONSTRAINT media_piece_types_pkey PRIMARY KEY (id);


--
-- Name: media_pieces media_pieces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_pieces
    ADD CONSTRAINT media_pieces_pkey PRIMARY KEY (id);


--
-- Name: media_runs media_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_runs
    ADD CONSTRAINT media_runs_pkey PRIMARY KEY (id);


--
-- Name: media_sequences media_sequences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_sequences
    ADD CONSTRAINT media_sequences_pkey PRIMARY KEY (id);


--
-- Name: mobile_phones mobile_phones_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_phones
    ADD CONSTRAINT mobile_phones_pkey PRIMARY KEY (id);


--
-- Name: mobile_registration_requests mobile_registration_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_registration_requests
    ADD CONSTRAINT mobile_registration_requests_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_grants oauth_access_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_grants
    ADD CONSTRAINT oauth_access_grants_pkey PRIMARY KEY (id);


--
-- Name: oauth_access_tokens oauth_access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_access_tokens
    ADD CONSTRAINT oauth_access_tokens_pkey PRIMARY KEY (id);


--
-- Name: oauth_applications oauth_applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oauth_applications
    ADD CONSTRAINT oauth_applications_pkey PRIMARY KEY (id);


--
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (id);


--
-- Name: recipient_types recipient_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipient_types
    ADD CONSTRAINT recipient_types_pkey PRIMARY KEY (id);


--
-- Name: recipients recipients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.recipients
    ADD CONSTRAINT recipients_pkey PRIMARY KEY (id);


--
-- Name: referral_clicks referral_clicks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_clicks
    ADD CONSTRAINT referral_clicks_pkey PRIMARY KEY (id);


--
-- Name: referral_credits referral_credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral_credits
    ADD CONSTRAINT referral_credits_pkey PRIMARY KEY (id);


--
-- Name: referrals referrals_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referrals
    ADD CONSTRAINT referrals_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sponster_widget_serve_logs sponster_widget_serve_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponster_widget_serve_logs
    ADD CONSTRAINT sponster_widget_serve_logs_pkey PRIMARY KEY (id);


--
-- Name: survey_answers survey_answers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_answers
    ADD CONSTRAINT survey_answers_pkey PRIMARY KEY (id);


--
-- Name: survey_categories survey_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_categories
    ADD CONSTRAINT survey_categories_pkey PRIMARY KEY (id);


--
-- Name: survey_question_surveys survey_question_surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_question_surveys
    ADD CONSTRAINT survey_question_surveys_pkey PRIMARY KEY (id);


--
-- Name: survey_questions survey_questions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_questions
    ADD CONSTRAINT survey_questions_pkey PRIMARY KEY (id);


--
-- Name: surveys surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys
    ADD CONSTRAINT surveys_pkey PRIMARY KEY (id);


--
-- Name: target_band_trait_groups target_band_trait_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_band_trait_groups
    ADD CONSTRAINT target_band_trait_groups_pkey PRIMARY KEY (id);


--
-- Name: target_bands target_bands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands
    ADD CONSTRAINT target_bands_pkey PRIMARY KEY (id);


--
-- Name: target_populations target_populations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_populations
    ADD CONSTRAINT target_populations_pkey PRIMARY KEY (id);


--
-- Name: targets targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets
    ADD CONSTRAINT targets_pkey PRIMARY KEY (id);


--
-- Name: tiqit_classes tiqit_classes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_classes
    ADD CONSTRAINT tiqit_classes_pkey PRIMARY KEY (id);


--
-- Name: trait_categories trait_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_categories
    ADD CONSTRAINT trait_categories_pkey PRIMARY KEY (id);


--
-- Name: trait_group_traits trait_group_traits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_group_traits
    ADD CONSTRAINT trait_group_traits_pkey PRIMARY KEY (id);


--
-- Name: trait_groups trait_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_groups
    ADD CONSTRAINT trait_groups_pkey PRIMARY KEY (id);


--
-- Name: traits traits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits
    ADD CONSTRAINT traits_pkey PRIMARY KEY (id);


--
-- Name: user_prefs user_prefs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_prefs
    ADD CONSTRAINT user_prefs_pkey PRIMARY KEY (id);


--
-- Name: user_proxies user_proxies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_proxies
    ADD CONSTRAINT user_proxies_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: worker_job_logs worker_job_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.worker_job_logs
    ADD CONSTRAINT worker_job_logs_pkey PRIMARY KEY (id);


--
-- Name: catalogs_creator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogs_creator_id_index ON public.catalogs USING btree (creator_id);


--
-- Name: content_groups_catalog_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_groups_catalog_id_index ON public.content_groups USING btree (catalog_id);


--
-- Name: content_pieces_content_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_pieces_content_group_id_index ON public.content_pieces USING btree (content_group_id);


--
-- Name: index_ad_events_on_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_campaign_id ON public.ad_events USING btree (campaign_id);


--
-- Name: index_ad_events_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_me_file_id ON public.ad_events USING btree (me_file_id);


--
-- Name: index_ad_events_on_media_piece_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_media_piece_id ON public.ad_events USING btree (media_piece_id);


--
-- Name: index_ad_events_on_media_piece_phase_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_media_piece_phase_id ON public.ad_events USING btree (media_piece_phase_id);


--
-- Name: index_ad_events_on_media_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_media_run_id ON public.ad_events USING btree (media_run_id);


--
-- Name: index_ad_events_on_offer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_offer_id ON public.ad_events USING btree (offer_id);


--
-- Name: index_ad_events_on_recipient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_recipient_id ON public.ad_events USING btree (recipient_id);


--
-- Name: index_ad_events_on_referral_credit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_referral_credit_id ON public.ad_events USING btree (referral_credit_id);


--
-- Name: index_ad_events_on_target_band_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_target_band_id ON public.ad_events USING btree (target_band_id);


--
-- Name: index_ad_events_on_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ad_events_on_target_id ON public.ad_events USING btree (target_id);


--
-- Name: index_bids_on_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bids_on_campaign_id ON public.bids USING btree (campaign_id);


--
-- Name: index_bids_on_media_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bids_on_media_run_id ON public.bids USING btree (media_run_id);


--
-- Name: index_bids_on_target_band_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bids_on_target_band_id ON public.bids USING btree (target_band_id);


--
-- Name: index_campaigns_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_campaigns_on_marketer_id ON public.campaigns USING btree (marketer_id);


--
-- Name: index_campaigns_on_media_sequence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_campaigns_on_media_sequence_id ON public.campaigns USING btree (media_sequence_id);


--
-- Name: index_campaigns_on_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_campaigns_on_target_id ON public.campaigns USING btree (target_id);


--
-- Name: index_ledger_entries_on_ad_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_ad_event_id ON public.ledger_entries USING btree (ad_event_id);


--
-- Name: index_ledger_entries_on_ledger_header_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_ledger_header_id ON public.ledger_entries USING btree (ledger_header_id);


--
-- Name: index_ledger_headers_on_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_headers_on_campaign_id ON public.ledger_headers USING btree (campaign_id);


--
-- Name: index_ledger_headers_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_headers_on_marketer_id ON public.ledger_headers USING btree (marketer_id);


--
-- Name: index_ledger_headers_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_headers_on_me_file_id ON public.ledger_headers USING btree (me_file_id);


--
-- Name: index_ledger_headers_on_recipient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_headers_on_recipient_id ON public.ledger_headers USING btree (recipient_id);


--
-- Name: index_marketer_users_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_marketer_users_on_marketer_id ON public.marketer_users USING btree (marketer_id);


--
-- Name: index_marketer_users_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_marketer_users_on_user_id ON public.marketer_users USING btree (user_id);


--
-- Name: index_me_file_tags_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_file_tags_on_me_file_id ON public.me_file_tags USING btree (me_file_id);


--
-- Name: index_me_file_tags_on_trait_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_file_tags_on_trait_id ON public.me_file_tags USING btree (trait_id);


--
-- Name: index_me_files_on_ledger_header_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_files_on_ledger_header_id ON public.me_files USING btree (ledger_header_id);


--
-- Name: index_me_files_on_referral_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_files_on_referral_code ON public.me_files USING btree (referral_code);


--
-- Name: index_me_files_on_referral_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_files_on_referral_id ON public.me_files USING btree (referral_id);


--
-- Name: index_me_files_on_sponster_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_files_on_sponster_token ON public.me_files USING btree (sponster_token);


--
-- Name: index_me_files_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_me_files_on_user_id ON public.me_files USING btree (user_id);


--
-- Name: index_media_pieces_on_ad_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_pieces_on_ad_category_id ON public.media_pieces USING btree (ad_category_id);


--
-- Name: index_media_pieces_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_pieces_on_marketer_id ON public.media_pieces USING btree (marketer_id);


--
-- Name: index_media_pieces_on_media_piece_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_pieces_on_media_piece_type_id ON public.media_pieces USING btree (media_piece_type_id);


--
-- Name: index_media_runs_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_runs_on_marketer_id ON public.media_runs USING btree (marketer_id);


--
-- Name: index_media_runs_on_media_piece_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_runs_on_media_piece_id ON public.media_runs USING btree (media_piece_id);


--
-- Name: index_media_runs_on_media_sequence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_runs_on_media_sequence_id ON public.media_runs USING btree (media_sequence_id);


--
-- Name: index_media_sequences_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_media_sequences_on_marketer_id ON public.media_sequences USING btree (marketer_id);


--
-- Name: index_mobile_phones_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mobile_phones_on_me_file_id ON public.mobile_phones USING btree (me_file_id);


--
-- Name: index_mobile_registration_requests_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mobile_registration_requests_on_me_file_id ON public.mobile_registration_requests USING btree (me_file_id);


--
-- Name: index_offers_on_campaign_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offers_on_campaign_id ON public.offers USING btree (campaign_id);


--
-- Name: index_offers_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offers_on_me_file_id ON public.offers USING btree (me_file_id);


--
-- Name: index_offers_on_media_piece_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offers_on_media_piece_id ON public.offers USING btree (media_piece_id);


--
-- Name: index_offers_on_media_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offers_on_media_run_id ON public.offers USING btree (media_run_id);


--
-- Name: index_offers_on_target_band_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_offers_on_target_band_id ON public.offers USING btree (target_band_id);


--
-- Name: index_recipients_on_referral_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recipients_on_referral_code ON public.recipients USING btree (referral_code);


--
-- Name: index_recipients_on_split_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recipients_on_split_code ON public.recipients USING btree (split_code);


--
-- Name: index_recipients_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_recipients_on_user_id ON public.recipients USING btree (user_id);


--
-- Name: index_referral_clicks_on_ad_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referral_clicks_on_ad_event_id ON public.referral_clicks USING btree (ad_event_id);


--
-- Name: index_referral_clicks_on_referral_credit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referral_clicks_on_referral_credit_id ON public.referral_clicks USING btree (referral_credit_id);


--
-- Name: index_referral_clicks_on_referral_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referral_clicks_on_referral_id ON public.referral_clicks USING btree (referral_id);


--
-- Name: index_referral_credits_on_ledger_entry_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referral_credits_on_ledger_entry_id ON public.referral_credits USING btree (ledger_entry_id);


--
-- Name: index_referral_credits_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referral_credits_on_me_file_id ON public.referral_credits USING btree (me_file_id);


--
-- Name: index_referrals_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referrals_on_me_file_id ON public.referrals USING btree (me_file_id);


--
-- Name: index_referrals_on_recipient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referrals_on_recipient_id ON public.referrals USING btree (recipient_id);


--
-- Name: index_referrals_on_referred_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_referrals_on_referred_me_file_id ON public.referrals USING btree (referred_me_file_id);


--
-- Name: index_sponster_widget_serve_logs_on_recipient_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sponster_widget_serve_logs_on_recipient_id ON public.sponster_widget_serve_logs USING btree (recipient_id);


--
-- Name: index_sponster_widget_serve_logs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sponster_widget_serve_logs_on_user_id ON public.sponster_widget_serve_logs USING btree (user_id);


--
-- Name: index_survey_answers_on_survey_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_answers_on_survey_question_id ON public.survey_answers USING btree (survey_question_id);


--
-- Name: index_survey_answers_on_trait_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_answers_on_trait_id ON public.survey_answers USING btree (trait_id);


--
-- Name: index_survey_question_surveys_on_survey_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_question_surveys_on_survey_id ON public.survey_question_surveys USING btree (survey_id);


--
-- Name: index_survey_question_surveys_on_survey_question_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_question_surveys_on_survey_question_id ON public.survey_question_surveys USING btree (survey_question_id);


--
-- Name: index_survey_questions_on_trait_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_survey_questions_on_trait_id ON public.survey_questions USING btree (trait_id);


--
-- Name: index_surveys_on_survey_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_surveys_on_survey_category_id ON public.surveys USING btree (survey_category_id);


--
-- Name: index_target_band_trait_groups_on_target_band_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_target_band_trait_groups_on_target_band_id ON public.target_band_trait_groups USING btree (target_band_id);


--
-- Name: index_target_band_trait_groups_on_trait_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_target_band_trait_groups_on_trait_group_id ON public.target_band_trait_groups USING btree (trait_group_id);


--
-- Name: index_target_bands_on_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_target_bands_on_target_id ON public.target_bands USING btree (target_id);


--
-- Name: index_target_populations_on_me_file_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_target_populations_on_me_file_id ON public.target_populations USING btree (me_file_id);


--
-- Name: index_target_populations_on_target_band_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_target_populations_on_target_band_id ON public.target_populations USING btree (target_band_id);


--
-- Name: index_targets_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_targets_on_marketer_id ON public.targets USING btree (marketer_id);


--
-- Name: index_trait_group_traits_on_trait_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trait_group_traits_on_trait_group_id ON public.trait_group_traits USING btree (trait_group_id);


--
-- Name: index_trait_group_traits_on_trait_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trait_group_traits_on_trait_id ON public.trait_group_traits USING btree (trait_id);


--
-- Name: index_trait_groups_on_marketer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trait_groups_on_marketer_id ON public.trait_groups USING btree (marketer_id);


--
-- Name: index_trait_groups_on_parent_trait_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_trait_groups_on_parent_trait_id ON public.trait_groups USING btree (parent_trait_id);


--
-- Name: index_traits_on_parent_trait_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traits_on_parent_trait_id ON public.traits USING btree (parent_trait_id);


--
-- Name: index_traits_on_trait_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traits_on_trait_category_id ON public.traits USING btree (trait_category_id);


--
-- Name: index_user_prefs_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_prefs_on_user_id ON public.user_prefs USING btree (user_id);


--
-- Name: index_user_proxies_on_proxy_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_proxies_on_proxy_user_id ON public.user_proxies USING btree (proxy_user_id);


--
-- Name: index_user_proxies_on_true_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_proxies_on_true_user_id ON public.user_proxies USING btree (true_user_id);


--
-- Name: index_users_on_confirmation_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_confirmation_token ON public.users USING btree (confirmation_token);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_mobile_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_mobile_number ON public.users USING btree (mobile_number);


--
-- Name: index_users_on_passage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_passage_id ON public.users USING btree (passage_id);


--
-- Name: index_users_on_referrer_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_referrer_code ON public.users USING btree (referrer_code);


--
-- Name: index_users_on_reset_password_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_reset_password_token ON public.users USING btree (reset_password_token);


--
-- Name: index_users_on_unlock_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_unlock_token ON public.users USING btree (unlock_token);


--
-- Name: index_users_on_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_username ON public.users USING btree (username);


--
-- Name: catalogs catalogs_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogs
    ADD CONSTRAINT catalogs_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.creators(id) ON DELETE CASCADE;


--
-- Name: content_groups content_groups_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_groups
    ADD CONSTRAINT content_groups_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalogs(id) ON DELETE CASCADE;


--
-- Name: content_pieces content_pieces_content_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_pieces
    ADD CONSTRAINT content_pieces_content_group_id_fkey FOREIGN KEY (content_group_id) REFERENCES public.content_groups(id) ON DELETE CASCADE;


--
-- Name: trait_values fk_parent_trait_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_values
    ADD CONSTRAINT fk_parent_trait_id FOREIGN KEY (parent_trait_id) REFERENCES public.traits(id) ON DELETE CASCADE;


--
-- Name: mobile_registration_requests fk_rails_0b1754b153; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mobile_registration_requests
    ADD CONSTRAINT fk_rails_0b1754b153 FOREIGN KEY (me_file_id) REFERENCES public.me_files(id);


--
-- Name: user_prefs fk_rails_2b2e5eb793; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_prefs
    ADD CONSTRAINT fk_rails_2b2e5eb793 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: sponster_widget_serve_logs fk_rails_f3f2cbf9b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponster_widget_serve_logs
    ADD CONSTRAINT fk_rails_f3f2cbf9b5 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: sponster_widget_serve_logs fk_rails_f62e0e2e8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sponster_widget_serve_logs
    ADD CONSTRAINT fk_rails_f62e0e2e8f FOREIGN KEY (recipient_id) REFERENCES public.recipients(id);


--
-- Name: tiqit_classes tiqit_classes_catalog_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_classes
    ADD CONSTRAINT tiqit_classes_catalog_id_fkey FOREIGN KEY (catalog_id) REFERENCES public.catalogs(id) ON DELETE CASCADE;


--
-- Name: tiqit_classes tiqit_classes_content_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_classes
    ADD CONSTRAINT tiqit_classes_content_group_id_fkey FOREIGN KEY (content_group_id) REFERENCES public.content_groups(id) ON DELETE CASCADE;


--
-- Name: tiqit_classes tiqit_classes_content_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_classes
    ADD CONSTRAINT tiqit_classes_content_piece_id_fkey FOREIGN KEY (content_piece_id) REFERENCES public.content_pieces(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20250501111230);
INSERT INTO public."schema_migrations" (version) VALUES (20250501132234);
INSERT INTO public."schema_migrations" (version) VALUES (20250501135921);
INSERT INTO public."schema_migrations" (version) VALUES (20250502071203);
INSERT INTO public."schema_migrations" (version) VALUES (20250502102111);
INSERT INTO public."schema_migrations" (version) VALUES (20250505113332);
INSERT INTO public."schema_migrations" (version) VALUES (20250505113718);
