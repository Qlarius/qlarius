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
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ad_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ad_categories (
    id bigint NOT NULL,
    name text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
    id bigint NOT NULL,
    offer_id bigint,
    offer_bid_amt numeric(8,2),
    offer_amount numeric NOT NULL,
    throttled boolean NOT NULL,
    demo boolean NOT NULL,
    offer_complete boolean NOT NULL,
    ip_address character varying(255),
    url character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: campaigns; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaigns (
    id bigint NOT NULL,
    target_id bigint NOT NULL,
    media_sequence_id bigint NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    starts_at timestamp(0) without time zone NOT NULL,
    ends_at timestamp(0) without time zone NOT NULL,
    payable boolean DEFAULT false NOT NULL,
    throttled boolean DEFAULT false NOT NULL,
    demo boolean DEFAULT false NOT NULL,
    deactivated_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
    title text,
    description text,
    type character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    catalog_id bigint
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
    title text NOT NULL,
    description text,
    content_type text NOT NULL,
    date_published date NOT NULL,
    length integer NOT NULL,
    preview_length integer NOT NULL,
    file_url text NOT NULL,
    preview_url text NOT NULL,
    price_default numeric(10,2) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    type character varying(255),
    content_group_id bigint NOT NULL
);


--
-- Name: content_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.content_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: content_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.content_id_seq OWNED BY public.content_pieces.id;


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
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_entries (
    id bigint NOT NULL,
    amount numeric(8,2) NOT NULL,
    description text NOT NULL,
    ledger_header_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    ad_event_id bigint,
    running_balance numeric(8,2) NOT NULL
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
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    description text NOT NULL,
    balance numeric(10,2) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: media_pieces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.media_pieces (
    id bigint NOT NULL,
    title text NOT NULL,
    body_copy text NOT NULL,
    display_url text NOT NULL,
    jump_url text NOT NULL,
    ad_category_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
    id bigint NOT NULL,
    frequency integer NOT NULL,
    frequency_buffer_hours integer NOT NULL,
    maximum_banner_count integer NOT NULL,
    banner_retry_buffer_hours integer NOT NULL,
    media_piece_id bigint NOT NULL,
    media_sequence_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
    id bigint NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offers (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    media_run_id bigint NOT NULL,
    phase_1_amount numeric(8,2) NOT NULL,
    phase_2_amount numeric(8,2) NOT NULL,
    amount numeric(10,2) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    throttled boolean DEFAULT false NOT NULL,
    demo boolean DEFAULT false NOT NULL,
    current boolean DEFAULT false NOT NULL,
    jobbed boolean DEFAULT false NOT NULL
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
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: survey_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.survey_categories (
    id bigint NOT NULL,
    name text NOT NULL,
    display_order integer DEFAULT 1 NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


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
-- Name: survey_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.survey_categories_id_seq OWNED BY public.survey_categories.id;


--
-- Name: surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.surveys (
    id bigint NOT NULL,
    name text NOT NULL,
    category_id bigint NOT NULL,
    display_order integer DEFAULT 1 NOT NULL,
    active boolean DEFAULT true NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: target_bands; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.target_bands (
    id bigint NOT NULL,
    target_id bigint NOT NULL,
    title text NOT NULL,
    description text,
    bullseye boolean DEFAULT false NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: target_bands_trait_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.target_bands_trait_groups (
    id bigint NOT NULL,
    target_band_id bigint NOT NULL,
    trait_group_id bigint NOT NULL
);


--
-- Name: target_bands_trait_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.target_bands_trait_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: target_bands_trait_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.target_bands_trait_groups_id_seq OWNED BY public.target_bands_trait_groups.id;


--
-- Name: targets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.targets (
    id bigint NOT NULL,
    name text NOT NULL,
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
-- Name: tiqit_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tiqit_types (
    id bigint NOT NULL,
    content_piece_id bigint NOT NULL,
    name character varying(255) NOT NULL,
    duration_hours integer,
    price numeric(10,2) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    CONSTRAINT duration_hours_must_be_positive CHECK ((duration_hours > 0))
);


--
-- Name: tiqit_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tiqit_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tiqit_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tiqit_types_id_seq OWNED BY public.tiqit_types.id;


--
-- Name: tiqits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tiqits (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    tiqit_type_id bigint NOT NULL,
    purchased_at timestamp(0) without time zone NOT NULL,
    expires_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: tiqits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tiqits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tiqits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tiqits_id_seq OWNED BY public.tiqits.id;


--
-- Name: trait_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trait_categories (
    id bigint NOT NULL,
    name text NOT NULL,
    display_order integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


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
-- Name: trait_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trait_categories_id_seq OWNED BY public.trait_categories.id;


--
-- Name: trait_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.trait_groups (
    id bigint NOT NULL,
    title text NOT NULL,
    description text,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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
    id bigint NOT NULL,
    trait_id bigint,
    name text NOT NULL,
    display_order integer,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    answer text
);


--
-- Name: trait_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.trait_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: trait_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.trait_values_id_seq OWNED BY public.trait_values.id;


--
-- Name: traits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traits (
    id bigint NOT NULL,
    name text NOT NULL,
    campaign_only boolean,
    "numeric" boolean,
    immutable boolean,
    display_order integer DEFAULT 1 NOT NULL,
    taggable boolean,
    is_date boolean,
    active boolean,
    input_type character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    category_id bigint NOT NULL,
    question text
);


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
-- Name: traits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traits_id_seq OWNED BY public.traits.id;


--
-- Name: traits_surveys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traits_surveys (
    id bigint NOT NULL,
    survey_id bigint NOT NULL,
    trait_id bigint NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: traits_surveys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traits_surveys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traits_surveys_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traits_surveys_id_seq OWNED BY public.traits_surveys.id;


--
-- Name: traits_trait_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traits_trait_groups (
    id bigint NOT NULL,
    trait_id bigint NOT NULL,
    trait_group_id bigint NOT NULL
);


--
-- Name: traits_trait_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traits_trait_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traits_trait_groups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traits_trait_groups_id_seq OWNED BY public.traits_trait_groups.id;


--
-- Name: user_trait_values; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_trait_values (
    id bigint NOT NULL,
    user_id bigint,
    trait_value_id bigint,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


--
-- Name: user_trait_values_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_trait_values_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_trait_values_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_trait_values_id_seq OWNED BY public.user_trait_values.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255) DEFAULT ''::character varying NOT NULL,
    encrypted_password character varying(255) DEFAULT ''::character varying NOT NULL,
    reset_password_token character varying(255),
    reset_password_sent_at timestamp(6) without time zone,
    remember_created_at timestamp(6) without time zone,
    sign_in_count integer DEFAULT 0,
    current_sign_in_at timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    current_sign_in_ip character varying(255),
    last_sign_in_ip character varying(255),
    confirmation_token character varying(255),
    confirmed_at timestamp(6) without time zone,
    confirmation_sent_at timestamp(6) without time zone,
    unconfirmed_email character varying(255),
    failed_attempts integer DEFAULT 0,
    unlock_token character varying(255),
    locked_at timestamp(6) without time zone,
    authentication_token character varying(255),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    referrer_code character varying(255),
    role character varying,
    passage_id character varying,
    mobile_number character varying
);


--
-- Name: users_unused; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_unused (
    id bigint NOT NULL,
    email public.citext NOT NULL,
    hashed_password character varying(255) NOT NULL,
    confirmed_at timestamp(0) without time zone,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
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

ALTER SEQUENCE public.users_id_seq OWNED BY public.users_unused.id;


--
-- Name: users_tokens_unused; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users_tokens_unused (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token bytea NOT NULL,
    context character varying(255) NOT NULL,
    sent_to character varying(255),
    inserted_at timestamp(0) without time zone NOT NULL
);


--
-- Name: users_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_tokens_id_seq OWNED BY public.users_tokens_unused.id;


--
-- Name: ad_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_categories ALTER COLUMN id SET DEFAULT nextval('public.ad_categories_id_seq'::regclass);


--
-- Name: ad_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_events ALTER COLUMN id SET DEFAULT nextval('public.ad_events_id_seq'::regclass);


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

ALTER TABLE ONLY public.content_pieces ALTER COLUMN id SET DEFAULT nextval('public.content_id_seq'::regclass);


--
-- Name: creators id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators ALTER COLUMN id SET DEFAULT nextval('public.creators_id_seq'::regclass);


--
-- Name: ledger_entries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries ALTER COLUMN id SET DEFAULT nextval('public.ledger_entries_id_seq'::regclass);


--
-- Name: ledger_headers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_headers ALTER COLUMN id SET DEFAULT nextval('public.ledger_headers_id_seq'::regclass);


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
-- Name: offers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers ALTER COLUMN id SET DEFAULT nextval('public.offers_id_seq'::regclass);


--
-- Name: survey_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_categories ALTER COLUMN id SET DEFAULT nextval('public.survey_categories_id_seq'::regclass);


--
-- Name: surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys ALTER COLUMN id SET DEFAULT nextval('public.surveys_id_seq'::regclass);


--
-- Name: target_bands id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands ALTER COLUMN id SET DEFAULT nextval('public.target_bands_id_seq'::regclass);


--
-- Name: target_bands_trait_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands_trait_groups ALTER COLUMN id SET DEFAULT nextval('public.target_bands_trait_groups_id_seq'::regclass);


--
-- Name: targets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets ALTER COLUMN id SET DEFAULT nextval('public.targets_id_seq'::regclass);


--
-- Name: tiqit_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_types ALTER COLUMN id SET DEFAULT nextval('public.tiqit_types_id_seq'::regclass);


--
-- Name: tiqits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqits ALTER COLUMN id SET DEFAULT nextval('public.tiqits_id_seq'::regclass);


--
-- Name: trait_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_categories ALTER COLUMN id SET DEFAULT nextval('public.trait_categories_id_seq'::regclass);


--
-- Name: trait_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_groups ALTER COLUMN id SET DEFAULT nextval('public.trait_groups_id_seq'::regclass);


--
-- Name: trait_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_values ALTER COLUMN id SET DEFAULT nextval('public.trait_values_id_seq'::regclass);


--
-- Name: traits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits ALTER COLUMN id SET DEFAULT nextval('public.traits_id_seq'::regclass);


--
-- Name: traits_surveys id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_surveys ALTER COLUMN id SET DEFAULT nextval('public.traits_surveys_id_seq'::regclass);


--
-- Name: traits_trait_groups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_trait_groups ALTER COLUMN id SET DEFAULT nextval('public.traits_trait_groups_id_seq'::regclass);


--
-- Name: user_trait_values id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_trait_values ALTER COLUMN id SET DEFAULT nextval('public.user_trait_values_id_seq'::regclass);


--
-- Name: users_tokens_unused id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens_unused ALTER COLUMN id SET DEFAULT nextval('public.users_tokens_id_seq'::regclass);


--
-- Name: users_unused id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_unused ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


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
-- Name: content_pieces content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.content_pieces
    ADD CONSTRAINT content_pkey PRIMARY KEY (id);


--
-- Name: creators creators_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.creators
    ADD CONSTRAINT creators_pkey PRIMARY KEY (id);


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
-- Name: offers offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: survey_categories survey_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.survey_categories
    ADD CONSTRAINT survey_categories_pkey PRIMARY KEY (id);


--
-- Name: surveys surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys
    ADD CONSTRAINT surveys_pkey PRIMARY KEY (id);


--
-- Name: target_bands target_bands_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands
    ADD CONSTRAINT target_bands_pkey PRIMARY KEY (id);


--
-- Name: target_bands_trait_groups target_bands_trait_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands_trait_groups
    ADD CONSTRAINT target_bands_trait_groups_pkey PRIMARY KEY (id);


--
-- Name: targets targets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.targets
    ADD CONSTRAINT targets_pkey PRIMARY KEY (id);


--
-- Name: tiqit_types tiqit_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_types
    ADD CONSTRAINT tiqit_types_pkey PRIMARY KEY (id);


--
-- Name: tiqits tiqits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqits
    ADD CONSTRAINT tiqits_pkey PRIMARY KEY (id);


--
-- Name: trait_categories trait_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_categories
    ADD CONSTRAINT trait_categories_pkey PRIMARY KEY (id);


--
-- Name: trait_groups trait_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_groups
    ADD CONSTRAINT trait_groups_pkey PRIMARY KEY (id);


--
-- Name: trait_values trait_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_values
    ADD CONSTRAINT trait_values_pkey PRIMARY KEY (id);


--
-- Name: traits traits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits
    ADD CONSTRAINT traits_pkey PRIMARY KEY (id);


--
-- Name: traits_surveys traits_surveys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_surveys
    ADD CONSTRAINT traits_surveys_pkey PRIMARY KEY (id);


--
-- Name: traits_trait_groups traits_trait_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_trait_groups
    ADD CONSTRAINT traits_trait_groups_pkey PRIMARY KEY (id);


--
-- Name: user_trait_values user_trait_values_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_trait_values
    ADD CONSTRAINT user_trait_values_pkey PRIMARY KEY (id);


--
-- Name: users_unused users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_unused
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users_tokens_unused users_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens_unused
    ADD CONSTRAINT users_tokens_pkey PRIMARY KEY (id);


--
-- Name: campaigns_target_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX campaigns_target_id_index ON public.campaigns USING btree (target_id);


--
-- Name: catalogs_creator_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX catalogs_creator_id_index ON public.catalogs USING btree (creator_id);


--
-- Name: content_groups_catalog_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX content_groups_catalog_id_index ON public.content_groups USING btree (catalog_id);


--
-- Name: ledger_entries_ledger_header_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ledger_entries_ledger_header_id_index ON public.ledger_entries USING btree (ledger_header_id);


--
-- Name: ledger_headers_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ledger_headers_user_id_index ON public.ledger_headers USING btree (user_id);


--
-- Name: media_pieces_ad_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX media_pieces_ad_category_id_index ON public.media_pieces USING btree (ad_category_id);


--
-- Name: media_runs_media_piece_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX media_runs_media_piece_id_index ON public.media_runs USING btree (media_piece_id);


--
-- Name: media_runs_media_sequence_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX media_runs_media_sequence_id_index ON public.media_runs USING btree (media_sequence_id);


--
-- Name: offers_media_run_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offers_media_run_id_index ON public.offers USING btree (media_run_id);


--
-- Name: offers_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offers_user_id_index ON public.offers USING btree (user_id);


--
-- Name: survey_categories_display_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX survey_categories_display_order_index ON public.survey_categories USING btree (display_order);


--
-- Name: surveys_active_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX surveys_active_index ON public.surveys USING btree (active);


--
-- Name: surveys_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX surveys_category_id_index ON public.surveys USING btree (category_id);


--
-- Name: surveys_display_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX surveys_display_order_index ON public.surveys USING btree (display_order);


--
-- Name: target_bands_target_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX target_bands_target_id_index ON public.target_bands USING btree (target_id);


--
-- Name: target_bands_trait_groups_target_band_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX target_bands_trait_groups_target_band_id_index ON public.target_bands_trait_groups USING btree (target_band_id);


--
-- Name: target_bands_trait_groups_target_band_id_trait_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX target_bands_trait_groups_target_band_id_trait_group_id_index ON public.target_bands_trait_groups USING btree (target_band_id, trait_group_id);


--
-- Name: target_bands_trait_groups_trait_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX target_bands_trait_groups_trait_group_id_index ON public.target_bands_trait_groups USING btree (trait_group_id);


--
-- Name: tiqit_types_content_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiqit_types_content_id_index ON public.tiqit_types USING btree (content_piece_id);


--
-- Name: tiqits_expires_at_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiqits_expires_at_index ON public.tiqits USING btree (expires_at);


--
-- Name: tiqits_tiqit_type_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiqits_tiqit_type_id_index ON public.tiqits USING btree (tiqit_type_id);


--
-- Name: tiqits_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX tiqits_user_id_index ON public.tiqits USING btree (user_id);


--
-- Name: trait_values_trait_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX trait_values_trait_id_index ON public.trait_values USING btree (trait_id);


--
-- Name: traits_category_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX traits_category_id_index ON public.traits USING btree (category_id);


--
-- Name: traits_display_order_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX traits_display_order_index ON public.traits USING btree (display_order);


--
-- Name: traits_surveys_survey_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX traits_surveys_survey_id_index ON public.traits_surveys USING btree (survey_id);


--
-- Name: traits_surveys_survey_id_trait_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX traits_surveys_survey_id_trait_id_index ON public.traits_surveys USING btree (survey_id, trait_id);


--
-- Name: traits_surveys_trait_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX traits_surveys_trait_id_index ON public.traits_surveys USING btree (trait_id);


--
-- Name: traits_trait_groups_trait_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX traits_trait_groups_trait_group_id_index ON public.traits_trait_groups USING btree (trait_group_id);


--
-- Name: traits_trait_groups_trait_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX traits_trait_groups_trait_id_index ON public.traits_trait_groups USING btree (trait_id);


--
-- Name: traits_trait_groups_trait_id_trait_group_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX traits_trait_groups_trait_id_trait_group_id_index ON public.traits_trait_groups USING btree (trait_id, trait_group_id);


--
-- Name: user_trait_values_trait_value_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_trait_values_trait_value_id_index ON public.user_trait_values USING btree (trait_value_id);


--
-- Name: user_trait_values_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX user_trait_values_user_id_index ON public.user_trait_values USING btree (user_id);


--
-- Name: user_trait_values_user_id_trait_value_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX user_trait_values_user_id_trait_value_id_index ON public.user_trait_values USING btree (user_id, trait_value_id);


--
-- Name: users_email_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_email_index ON public.users_unused USING btree (email);


--
-- Name: users_tokens_context_token_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX users_tokens_context_token_index ON public.users_tokens_unused USING btree (context, token);


--
-- Name: users_tokens_user_id_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_tokens_user_id_index ON public.users_tokens_unused USING btree (user_id);


--
-- Name: ad_events ad_events_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ad_events
    ADD CONSTRAINT ad_events_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offers(id);


--
-- Name: campaigns campaigns_media_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_media_sequence_id_fkey FOREIGN KEY (media_sequence_id) REFERENCES public.media_sequences(id) ON DELETE CASCADE;


--
-- Name: campaigns campaigns_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaigns
    ADD CONSTRAINT campaigns_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.targets(id) ON DELETE CASCADE;


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
-- Name: ledger_entries ledger_entries_ad_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_ad_event_id_fkey FOREIGN KEY (ad_event_id) REFERENCES public.ad_events(id);


--
-- Name: ledger_entries ledger_entries_ledger_header_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_ledger_header_id_fkey FOREIGN KEY (ledger_header_id) REFERENCES public.ledger_headers(id) ON DELETE CASCADE;


--
-- Name: ledger_headers ledger_headers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_headers
    ADD CONSTRAINT ledger_headers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users_unused(id) ON DELETE CASCADE;


--
-- Name: media_pieces media_pieces_ad_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_pieces
    ADD CONSTRAINT media_pieces_ad_category_id_fkey FOREIGN KEY (ad_category_id) REFERENCES public.ad_categories(id);


--
-- Name: media_runs media_runs_media_piece_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_runs
    ADD CONSTRAINT media_runs_media_piece_id_fkey FOREIGN KEY (media_piece_id) REFERENCES public.media_pieces(id) ON DELETE CASCADE;


--
-- Name: media_runs media_runs_media_sequence_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.media_runs
    ADD CONSTRAINT media_runs_media_sequence_id_fkey FOREIGN KEY (media_sequence_id) REFERENCES public.media_sequences(id) ON DELETE CASCADE;


--
-- Name: offers offers_media_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_media_run_id_fkey FOREIGN KEY (media_run_id) REFERENCES public.media_runs(id);


--
-- Name: offers offers_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offers
    ADD CONSTRAINT offers_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users_unused(id) ON DELETE CASCADE;


--
-- Name: surveys surveys_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.surveys
    ADD CONSTRAINT surveys_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.survey_categories(id) ON DELETE RESTRICT;


--
-- Name: target_bands target_bands_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands
    ADD CONSTRAINT target_bands_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.targets(id) ON DELETE CASCADE;


--
-- Name: target_bands_trait_groups target_bands_trait_groups_target_band_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands_trait_groups
    ADD CONSTRAINT target_bands_trait_groups_target_band_id_fkey FOREIGN KEY (target_band_id) REFERENCES public.target_bands(id) ON DELETE CASCADE;


--
-- Name: target_bands_trait_groups target_bands_trait_groups_trait_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.target_bands_trait_groups
    ADD CONSTRAINT target_bands_trait_groups_trait_group_id_fkey FOREIGN KEY (trait_group_id) REFERENCES public.trait_groups(id) ON DELETE CASCADE;


--
-- Name: tiqit_types tiqit_types_content_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqit_types
    ADD CONSTRAINT tiqit_types_content_id_fkey FOREIGN KEY (content_piece_id) REFERENCES public.content_pieces(id) ON DELETE CASCADE;


--
-- Name: tiqits tiqits_tiqit_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqits
    ADD CONSTRAINT tiqits_tiqit_type_id_fkey FOREIGN KEY (tiqit_type_id) REFERENCES public.tiqit_types(id) ON DELETE SET NULL;


--
-- Name: tiqits tiqits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tiqits
    ADD CONSTRAINT tiqits_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users_unused(id) ON DELETE CASCADE;


--
-- Name: trait_values trait_values_trait_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.trait_values
    ADD CONSTRAINT trait_values_trait_id_fkey FOREIGN KEY (trait_id) REFERENCES public.traits(id) ON DELETE CASCADE;


--
-- Name: traits traits_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits
    ADD CONSTRAINT traits_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.trait_categories(id);


--
-- Name: traits_surveys traits_surveys_survey_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_surveys
    ADD CONSTRAINT traits_surveys_survey_id_fkey FOREIGN KEY (survey_id) REFERENCES public.surveys(id) ON DELETE CASCADE;


--
-- Name: traits_surveys traits_surveys_trait_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_surveys
    ADD CONSTRAINT traits_surveys_trait_id_fkey FOREIGN KEY (trait_id) REFERENCES public.traits(id) ON DELETE CASCADE;


--
-- Name: traits_trait_groups traits_trait_groups_trait_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_trait_groups
    ADD CONSTRAINT traits_trait_groups_trait_group_id_fkey FOREIGN KEY (trait_group_id) REFERENCES public.trait_groups(id) ON DELETE CASCADE;


--
-- Name: traits_trait_groups traits_trait_groups_trait_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traits_trait_groups
    ADD CONSTRAINT traits_trait_groups_trait_id_fkey FOREIGN KEY (trait_id) REFERENCES public.traits(id) ON DELETE CASCADE;


--
-- Name: user_trait_values user_trait_values_trait_value_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_trait_values
    ADD CONSTRAINT user_trait_values_trait_value_id_fkey FOREIGN KEY (trait_value_id) REFERENCES public.trait_values(id) ON DELETE CASCADE;


--
-- Name: user_trait_values user_trait_values_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_trait_values
    ADD CONSTRAINT user_trait_values_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users_unused(id) ON DELETE CASCADE;


--
-- Name: users_tokens_unused users_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users_tokens_unused
    ADD CONSTRAINT users_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users_unused(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20250304120240);
INSERT INTO public."schema_migrations" (version) VALUES (20250304120310);
INSERT INTO public."schema_migrations" (version) VALUES (20250305084022);
INSERT INTO public."schema_migrations" (version) VALUES (20250305103002);
INSERT INTO public."schema_migrations" (version) VALUES (20250305105617);
INSERT INTO public."schema_migrations" (version) VALUES (20250305114800);
INSERT INTO public."schema_migrations" (version) VALUES (20250305114943);
INSERT INTO public."schema_migrations" (version) VALUES (20250305115000);
INSERT INTO public."schema_migrations" (version) VALUES (20250305135159);
INSERT INTO public."schema_migrations" (version) VALUES (20250305140215);
INSERT INTO public."schema_migrations" (version) VALUES (20250311095725);
INSERT INTO public."schema_migrations" (version) VALUES (20250320125705);
INSERT INTO public."schema_migrations" (version) VALUES (20250326174711);
INSERT INTO public."schema_migrations" (version) VALUES (20250407131128);
INSERT INTO public."schema_migrations" (version) VALUES (20250414112725);
INSERT INTO public."schema_migrations" (version) VALUES (20250424102322);
INSERT INTO public."schema_migrations" (version) VALUES (20250428111311);
