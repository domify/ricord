completed: M1, M2

| file | verdict | target | milestone | reason | done |
|---|---|---|---|---|---|
| test/adapter_adapter_matrix_doc_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/adapter_db_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/adapter_pg_db_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/adapter_pg_placeholder_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/adapter_pg_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/adapter_placeholder_rewrite_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/adapter_sqlite_db_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/adapter_sqlite_pragmas_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/adapter_sqlite_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/adapter_test_helpers_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/attribute_spec_models.ri | drop |  |  | support file, not a test | |
| test/convenience_models.ri | drop |  |  | support file, not a test | |
| test/converter_spec_support.ri | drop |  |  | support file, not a test | |
| test/delete_test.ri | port | test/crud_test.ri | M1 | rollback restoring a destroyed record's flags deferred: store flags are not reset when a write rolls back | x |
| test/dirty_family_models.ri | drop |  |  | support file, not a test | |
| test/encryption_codec_regression_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_adapter_read_tape_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/grant_associations_belongs_to_extras_test.ri | port | test/association_test.ri | M3 | the writer sets the key and marks it changed; belongs_to default:, the required-parent validation and saving an unsaved parent with the child are not in doc/DESIGN.md | x |
| test/grant_associations_collection_build_create_test.ri | port | test/association_test.ri | M3 | build/create through has_many set the key, an invalid record is returned unsaved with errors, a loaded collection sees a created record; `new` through the association is named `build` (ris treats an instance method `new` as in-place construction, which may not grow the store); block, Hash and Array forms, inverse_of and RecordNotSaved for an unsaved owner are not in doc/DESIGN.md | x |
| test/grant_associations_collection_methods_test.ri | port | test/association_test.ri | M3 | build/create ported (M3 part A); delete_all/destroy_all through the association wait for the M4 Query methods | |
| test/grant_associations_collection_query_methods_test.ri | port | test/association_test.ri | M3 | count, size, exists?/any?/empty? on loaded and unloaded associations; default scopes are not in doc/DESIGN.md | x |
| test/grant_associations_dependent_delete_all_test.ri | port | test/association_test.ri | M3 | dependent: is M3 part B | |
| test/grant_associations_has_many_foreign_key_forms_test.ri | port | test/association_test.ri | M3 | foreign_key: takes a Symbol; the bare-identifier form is Grant syntax | x |
| test/grant_associations_has_many_test.ri | port | test/association_test.ri | M3 | count/size, raw where with order, find_by, find; find_by!/find! are find_by/find returning nil/RecordNotFound; a custom primary key is not in doc/DESIGN.md (id is the key) | x |
| test/grant_associations_has_many_through_test.ri | defer |  |  | has_many :through is in Future Improvements | |
| test/grant_associations_has_one_test.ri | port | test/association_test.ri | M3 | has_one reader, nil when none, class_name and foreign_key; a has_one writer on the parent and a custom primary key are not in doc/DESIGN.md | x |
| test/grant_associations_has_one_through_test.ri | defer |  |  | has_one :through is in Future Improvements | |
| test/grant_associations_polymorphic_simple_test.ri | defer |  |  | polymorphic associations are in Future Improvements | |
| test/grant_associations_w6_collection_finders_test.ri | port | test/association_test.ri | M3 | first/last with LIMIT, other owners' rows not found, a loaded collection answers without a query; first(n), take, second..forty_two and find(ids) are not in the design's query API; the :through part is in Future Improvements | x |
| test/grant_associations_w6_collection_relation_test.ri | port | test/association_test.ri | M3 | order/limit through the association ported; pluck, aggregates, distinct, batches and joins wait for M4 | |
| test/grant_attribute_api_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_alias_attribute_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_assign_attributes_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_before_type_cast_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_cache_key_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_enum_options_test.ri | defer |  |  | enums are in Future Improvements | |
| test/grant_attributes_introspection_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_normalized_query_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_normalizes_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_reflection_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_attributes_store_accessor_test.ri | port | test/json_field_test.ri | M2 | store_accessor becomes json_field: defaults without a value, typed keys written and persisted, a key write marks the json column changed and an UPDATE saves it from a loaded record; per-key `<key>_changed?`/`_was`, the parse cache and prefix:/suffix: names are not in doc/DESIGN.md | x |
| test/grant_attributes_w6_alias_query_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_boolean_predicates_test.ri | drop |  |  | schema tenants and replica lag tracking removed | |
| test/grant_callbacks_abort_test.ri | port | test/callback_test.ri | M2 | a refusal at each create, update and destroy stage runs no later callback, returns CallbackError naming the callback, leaves no row (or the old row) and keeps new_record? and the unsaved changes; a refused save inside a write rolls back only its savepoint; after_rollback is M2 part B; an after_destroy refusal rolls the DELETE back (Grant kept it deleted); the refusal is the returned CallbackError, not an errors entry | x |
| test/grant_callbacks_after_commit_timing_test.ri | port | test/after_commit_test.ri | M2 | nothing runs inside the write, once after the outermost COMMIT, create/update/destroy forms, after_rollback (not after_commit) on a returned failure and on tx.roll_back, a lone save runs its work and no rollback item, two models in one commit, a released savepoint waits for the outer COMMIT, a savepoint rollback runs only its after_rollback, an outer rollback after a released savepoint runs both rollbacks; after_rollback is a class method with the key (nil for a create), not the record; independent: transactions and enqueue_pending_callback are not in doc/DESIGN.md | x |
| test/grant_callbacks_after_save_commit_test.ri | port | test/after_commit_test.ri | M2 | after_save_commit on create and update, not on destroy, once with after_create_commit beside it, a create then update in one write is one create, nothing on rollback | x |
| test/grant_callbacks_around_callbacks_test.ri | drop |  |  | around/prepend/proc callbacks are not in v1 | |
| test/grant_callbacks_around_validation_test.ri | drop |  |  | around/prepend/proc callbacks are not in v1 | |
| test/grant_callbacks_callbacks_test.ri | port | test/callback_test.ri | M2 | create, update and destroy callback order, a callback's error is returned (not swallowed), a before_create callback fills a column before the INSERT; the after_commit forms are M2 part B; after_initialize, after_find and after_touch are not in doc/DESIGN.md; calling a callback by hand is not in Ricord (callbacks are named methods) | x |
| test/grant_callbacks_commit_dedup_savepoint_test.ri | port | test/after_commit_test.ri | M2 | an update undone by a savepoint rollback runs no update item and the create runs once, after_rollback runs at the ROLLBACK TO before the commit items, a create or update then destroy resolves to a destroy, a rolled-back destroy runs after_rollback with its key, repeated updates rolled back run after_rollback once; after_rollback on: is not in doc/DESIGN.md, and a rolled-back create then update runs after_rollback twice (the create's item has key -1, so it cannot merge with the update's) | x |
| test/grant_callbacks_commit_on_option_test.ri | port | test/after_commit_test.ri | M2 | on: [:create, :update] skips a destroy, an after_commit without on: runs for all three, repeated saves in one write run once per record and not per model, a later write runs again; after_rollback on: is not in doc/DESIGN.md | x |
| test/grant_callbacks_lifecycle_callbacks_test.ri | port | test/callback_test.ri | M2 | valid? runs before_validation then after_validation, create/update/destroy order; block-form callbacks become method names; after_commit and after_rollback are M2 part B; after_initialize, after_find and after_touch are not in doc/DESIGN.md | x |
| test/grant_callbacks_prepend_test.ri | drop |  |  | around/prepend/proc callbacks are not in v1 | |
| test/grant_callbacks_proc_conditions_test.ri | drop |  |  | around/prepend/proc callbacks are not in v1 | |
| test/grant_callbacks_run_callbacks_test.ri | drop |  |  | around/prepend/proc callbacks are not in v1 | |
| test/grant_columns_primary_key_auto_default_test.ri | port | test/schema_test.ri | M1 | only the integer auto key applies; String and explicit keys dropped (id is always INTEGER AUTOINCREMENT) | x |
| test/grant_columns_primary_key_test.ri | drop |  |  | custom and non-auto primary keys removed (id is always INTEGER AUTOINCREMENT) | |
| test/grant_columns_uuid_test.ri | drop |  |  | UUID primary keys removed | |
| test/grant_columns_w6b_bigdecimal_column_test.ri | defer |  |  | `:decimal` waits for `Ricord::Decimal` | |
| test/grant_config_database_configurations_adapters_test.ri | drop |  |  | YAML database configurations and adapter registry replaced by Ricord.open(uri) | |
| test/grant_config_database_configurations_test.ri | drop |  |  | YAML database configurations and adapter registry replaced by Ricord.open(uri) | |
| test/grant_config_url_scheme_test.ri | port | test/errors_test.ri | M1 | only scheme to dialect applies; PostgreSQL, MySQL and the adapter registry dropped | x |
| test/grant_connection_abstract_inheritance_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_connected_to_predicates_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_connects_to_hash_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_context_scoping_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_database_context_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_disconnect_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_handling_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_health_recovery_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_management_simple_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_management_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_pool_exhaustion_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_pool_reaper_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_prepared_statements_test.ri | drop |  |  | driver prepares each statement; no fibers in ris | |
| test/grant_connection_reconnect_liveness_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_reconnect_pg_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_connection_reconnect_policy_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_reconnect_refusal_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_reconnect_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_replica_routing_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_routing_two_files_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_w6_abstract_class_routing_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_w6_connected_to_role_hash_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_w6_connects_to_registry_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_w6_database_tasks_configuration_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_w6_no_database_error_test.ri | port | test/errors_test.ri | M1 | SQLite only: libturso dies of a memory fault opening a file in a missing directory; pools and refused servers dropped | x |
| test/grant_connection_w6_reconnect_idle_pg_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_connection_w6_reconnect_idle_policy_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_w6_reconnect_idle_test.ri | drop |  |  | reconnect policies removed (a session owns its connection for its block) | |
| test/grant_connection_w6_statement_invalid_sql_adapter_test.ri | port | test/errors_test.ri | M1 | raw scalar/exec errors; DatabaseError has no sql field, the message names the column | x |
| test/grant_connection_w6_statement_invalid_sql_facade_test.ri | port | test/errors_test.ri | M1 | raw scalar/query errors; select_rows/select_one facade dropped | x |
| test/grant_connection_w6_statement_invalid_sql_pinned_test.ri | port | test/errors_test.ri | M1 | an error inside a write rolls it back; pinned connections dropped | x |
| test/grant_connection_w6_statement_invalid_sql_query_aggregations_test.ri | defer |  |  | sum/avg/min/max and grouped count are not in Ricord | |
| test/grant_connection_w6_statement_invalid_sql_query_mutations_test.ri | defer |  |  | update_all, delete_all and batched each are not built yet | |
| test/grant_connection_w6_statement_invalid_sql_query_reads_test.ri | port | test/errors_test.ri | M1 | to_a/first/find_by errors and binds kept out of the message; last and bind caps not in Ricord | x |
| test/grant_connection_w6_statement_invalid_sql_query_values_test.ri | port | test/errors_test.ri | M1 | count and exists? errors; pluck, pick and ids not built yet | x |
| test/grant_connection_w6_statement_invalid_sql_test.ri | port | test/errors_test.ri | M1 | insert and update errors; a read of a missing double-quoted column returns its name as text (SQLite/Turso double-quoted string literals), so it is not tested | x |
| test/grant_connection_with_connection_pool_test.ri | drop |  |  | connection pools, roles and routing removed (one connection per session) | |
| test/grant_connection_with_connection_test.ri | drop |  |  | pinned connections and roles removed (one connection per session) | |
| test/grant_convenience_class_destroy_update_test.ri | defer |  |  | class-level destroy(id), delete(id), update(id) are not in Ricord; instance find + destroy is in test/crud_test.ri | |
| test/grant_convenience_create_block_array_test.ri | defer |  |  | block form of new/create and create from an array not built and not planned in doc/DESIGN.md; its invalid-record cases need validations (M2) | |
| test/grant_convenience_create_or_find_by_test.ri | defer |  |  | create_or_find_by not built and not planned in doc/DESIGN.md | |
| test/grant_convenience_create_with_test.ri | defer |  |  | create_with and scope attributes not built and not planned in doc/DESIGN.md | |
| test/grant_convenience_find_by_ids_test.ri | defer |  |  | find with several ids not built and not planned in doc/DESIGN.md (where(id: [...]) keeps no id order and reports no missing ids) | |
| test/grant_convenience_find_or_create_by_test.ri | defer |  |  | find_or_create_by, find_or_initialize_by, first_or_create and scope attributes on create not built and not planned in doc/DESIGN.md | |
| test/grant_convenience_methods_query_test.ri | port | test/crud_test.ri | M4 | pluck, pick and batches are M4; sole, find_sole_by, annotate, destroy_by, delete_by, touch_all and update_counters not built and not planned in doc/DESIGN.md | |
| test/grant_convenience_relation_finders_test.ri | port | test/crud_test.ri | M1 | find_by and find on a query, nil as IS NULL, query unchanged; find_by!, find_sole_by and named scopes not built | x |
| test/grant_converters_enum_test.ri | defer |  |  | enums are in Future Improvements | |
| test/grant_converters_json_test.ri | defer |  |  | converting an object to and from JSON text (Converters::Json over String, JSON::Any and Bytes) is not in doc/DESIGN.md; a :json column holds text and json_field reads typed keys | |
| test/grant_converters_pg_numeric_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_dirty_changes_to_save_test.ri | port | test/dirty_test.ri | M2 | pending changes as changed?/changed_attributes, cleared by a save; changes_to_save hashes, attributes_in_database, `<col>_in_database`, change_to_be_saved tuples and the GC allocation check are not in doc/DESIGN.md (Ricord keeps no old values) | x |
| test/grant_dirty_dirty_control_test.ri | defer |  |  | restore_attributes, clear_changes_information, changes_applied, clear_attribute_changes and will_change! are not in doc/DESIGN.md (Ricord keeps no old values); Array columns are not Ricord columns | |
| test/grant_dirty_dirty_tracking_test.ri | port | test/dirty_test.ri | M2 | `<col>_changed?`, changed?, changed_attributes (several columns), cleared after a save, setting the saved value is no change; `_was`, `_change`, changes, restore_attributes, previous_changes and a revert to the original clearing the mark need old values, not in doc/DESIGN.md; a new record's given columns count as changed (they are what the INSERT writes) | x |
| test/grant_dirty_mutation_detection_test.ri | defer |  |  | in-place mutation detection of Array and serialized columns is not in Ricord (no Array columns, a :json column is text; a json_field write marks the column, in json_field_test) | |
| test/grant_dirty_saved_changes_test.ri | defer |  |  | saved_changes, saved_change_to_`<col>`? with from:/to:, previously_was and previously_changed? need old values, not in doc/DESIGN.md | |
| test/grant_encryption_context_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_database_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_key_rotation_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_migration_helpers_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_options_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_previous_schemes_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_transparent_column_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_unencrypted_fallback_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_changes_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_context_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_database_readers_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_eager_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_marker_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_memory_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_reads_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_serialization_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_encryption_w6b_lazy_decrypt_test.ri | defer |  |  | encryption is in Future Improvements | |
| test/grant_enum_attributes_test.ri | defer |  |  | enums are in Future Improvements | |
| test/grant_error_error_test.ri | drop |  |  | its one case is an error entry's to_json; an ErrorEntry is store data with no JSON form, rendering errors is the application's | |
| test/grant_errors_constraint_translation_classification_test.ri | defer |  |  | Ricord does not classify database errors into kinds; DatabaseError carries the driver code only | |
| test/grant_errors_constraint_translation_contention_test.ri | defer |  |  | pools dropped; lock-wait classification not built (a busy database is a plain DatabaseError) | |
| test/grant_errors_constraint_translation_pg_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_errors_constraint_translation_test.ri | drop |  |  | PostgreSQL or MySQL error translation and pool errors | |
| test/grant_errors_constraint_translation_writes_test.ri | port | test/errors_test.ri | M1 | unique, foreign key and NOT NULL failures as DatabaseError, write rollback, record stays new; no kinds such as RecordNotUnique, no sql/binds fields; code checked on SQLite only (Turso errors carry -1) | x |
| test/grant_errors_errors_api_test.ri | port | test/validation_test.ri | M2 | add (also on :base), on, full_messages (base alone), empty?, any?, size, entries per record, a validation filling errors; where, of_type, include?, attribute_names, group_by_attribute, to_hash, merge, clear, first/last, each/map/select, to_json, to_s and typed entries are not in the Errors view doc/DESIGN.md lists | x |
| test/grant_errors_statement_invalid_test.ri | drop |  |  | DatabaseError has no sql or binds fields by design (text extras live in the message); binds kept out of the message is covered in test/errors_test.ri | |
| test/grant_errors_taxonomy_test.ri | port | test/errors_test.ri | M1 | every error is a Failure, message format, RecordInvalid joining, 240-byte cut; class hierarchy and historical aliases dropped (flat structs); save!/create! raising RecordInvalid is M2 | x |
| test/grant_exceptions_record_invalid_test.ri | port | test/validation_test.ri | M2 | an invalid save returns RecordInvalid whose message holds the first full message and count; the error holds no record (flat struct) | x |
| test/grant_exceptions_record_not_destroyed_test.ri | port | test/callback_test.ri | M2 | a destroy refused by before_destroy returns CallbackError naming the callback and keeps the row; the error holds no record (flat struct) | x |
| test/grant_fiber_connection_context_test.ri | drop |  |  | driver prepares each statement; no fibers in ris | |
| test/grant_integrators_find_or_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_locking_lock_clause_test.ri | defer |  |  | locking is not in v1 (SQLite writes are serialized) | |
| test/grant_locking_lock_wait_single_connection_test.ri | defer |  |  | locking is not in v1 (SQLite writes are serialized) | |
| test/grant_locking_lock_wait_test.ri | defer |  |  | locking is not in v1 (SQLite writes are serialized) | |
| test/grant_locking_pessimistic_test.ri | defer |  |  | locking is not in v1 (SQLite writes are serialized) | |
| test/grant_locking_unsaved_changes_lock_test.ri | defer |  |  | locking is not in v1 (SQLite writes are serialized) | |
| test/grant_locking_with_lock_test.ri | defer |  |  | locking is not in v1 (SQLite writes are serialized) | |
| test/grant_migrator_defaults_test.ri | defer |  |  | migrations are in Future Improvements | |
| test/grant_migrator_migrator_test.ri | defer |  |  | migrations are in Future Improvements | |
| test/grant_normalization_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_notifications_transaction_events_test.ri | defer |  |  | transaction start/commit/rollback notifications and subscriptions are not in doc/DESIGN.md; the SQL log (statements) is Ricord's only view of BEGIN/COMMIT/ROLLBACK | |
| test/grant_perf_w6_primary_key_lookup_clauses_test.ri | port | test/group_loading_test.ri | M3 | chained queries keep their own conditions (the persistent where chain replaces where_fields); read with to_a, pluck is M4 | x |
| test/grant_perf_w6_primary_key_lookup_keys_test.ri | port | test/group_loading_test.ri | M3 | find again and again with one identical SELECT, Int32 key, inside a write, missing key; String keys and String primary keys are not in doc/DESIGN.md (id is Int64) | x |
| test/grant_perf_w6_primary_key_lookup_scopes_test.ri | defer |  |  | default scopes, unscoped and scoping blocks are not in doc/DESIGN.md | |
| test/grant_perf_w6_primary_key_lookup_test.ri | defer |  |  | the query cache and query-log tags are not in doc/DESIGN.md | |
| test/grant_perf_w6_sqlite_time_parse_test.ri | port | test/types_test.ri | M1 | runs on both engines; the save round trip is the existing Time test | x |
| test/grant_perf_w6_statement_count_create_find_test.ri | port | test/group_loading_test.ri | M3 | create is BEGIN IMMEDIATE, INSERT ... RETURNING, COMMIT; find is one SELECT; Grant's operator-form where (:gt, :like) is replaced by typed where and raw SQL, covered in crud_test | x |
| test/grant_perf_w6_statement_count_test.ri | defer |  |  | a save of an unchanged record still runs BEGIN IMMEDIATE and COMMIT (no lazy write that sends nothing until a statement); the transaction materializer is Grant-internal | |
| test/grant_perf_w6_statement_count_writes_test.ri | port | test/group_loading_test.ri | M3 | UPDATE inside BEGIN IMMEDIATE/COMMIT, one BEGIN and one COMMIT around several saves; a callback's write and rollback are covered by callback_test and write_test; restoring a record's state on rollback deferred as in delete_test | x |
| test/grant_persistence_destroyed_guard_test.ri | port | test/crud_test.ri | M1 | in-memory reads after destroy, no row written back, live records unaffected; the RecordDestroyedError guard is not built (save of a destroyed record runs an UPDATE that changes no row); frozen?, update*, touch and increment not built | x |
| test/grant_persistence_direct_persistence_test.ri | defer |  |  | update_columns, increment!, touch and read-only attributes not built and not planned in doc/DESIGN.md; per-column dirty API is M2 | |
| test/grant_persistence_dirty_tracking_api_test.ri | defer |  |  | will_save_change_to_`<col>`? with from:/to: is not in doc/DESIGN.md, and a new record's given columns count as changed in Ricord (Grant starts clean) | |
| test/grant_persistence_dup_clone_test.ri | defer |  |  | record dup and clone are not built | |
| test/grant_persistence_equality_test.ri | defer |  |  | record == and hash by table and id are not built (two finds of one row are different records) | |
| test/grant_persistence_helpers_operations_test.ri | defer |  |  | update_attribute, update_columns, increment, decrement and toggle are not built; the callback and validation parts are M2 | |
| test/grant_persistence_ivar_initializer_save_test.ri | drop |  |  | a generated-Amber-app probe of Grant class-level settings (replica lag, default scope); saving is covered by crud_test | |
| test/grant_persistence_mass_assignment_test.ri | defer |  |  | update(**attrs) and previous_changes are not built; a wrong value type is a build error in the typed new, not a ConversionError | |
| test/grant_persistence_no_touching_test.ri | port | test/dirty_test.ri | M2 | a normal save that changes a column still moves updated_at; touch, no_touching, suppress, STI subclasses and fiber-local state are not in doc/DESIGN.md | x |
| test/grant_persistence_primary_key_mass_assignment_test.ri | defer |  |  | new and create take no id: argument, so an explicit primary key cannot be given | |
| test/grant_persistence_read_only_transaction_create_test.ri | defer |  |  | read-only transactions are PostgreSQL/MySQL only; the SQLite scenario needs create with an explicit id: and RecordNotSaved with a cause, neither built | |
| test/grant_persistence_touch_options_test.ri | port | test/dirty_test.ri | M2 | a save that changes a column stamps updated_at in the same UPDATE; touch(time:), touch of named columns, increment!/decrement! with touch: and update_column are not in doc/DESIGN.md | x |
| test/grant_persistence_transaction_lifecycle_failure_test.ri | port | test/after_commit_test.ri | M2 | a failing after_commit item makes the write return AfterCommitError with its message and record id, the row stays committed and no write is left open; around_save is not in doc/DESIGN.md | x |
| test/grant_persistence_transaction_lifecycle_state_test.ri | defer |  |  | store flags and values are not reset when a write rolls back; the savepoint row behaviour is already in write_test | |
| test/grant_persistence_update_counters_test.ri | defer |  |  | update_counters (and touch) are not built | |
| test/grant_persistence_w6_assign_unknown_key_test.ri | port | test/refused/unknown_column_key.ri | M1 | an unknown key is a build error of the typed new; assign_attributes, attributes=, alias_attribute and string-keyed hashes not in Ricord | x |
| test/grant_persistence_w6_model_name_test.ri | defer |  |  | model_name, pluralization, human names and I18n are not built | |
| test/grant_persistence_w6_timestamps_test.ri | port | test/dirty_test.ri | M2 | the stamp kept in memory equals the stored one (microseconds, cut by write_time); precision:, date_timestamps, set_timestamps, touch, touch_all and record_timestamps= are not in doc/DESIGN.md | x |
| test/grant_public_api_return_types_associations_test.ri | port | test/association_test.ri | M3 | belongs_to/has_one return Model, Nil or DatabaseError and has_many a Model::Query, checked at compile time; polymorphic (as:) and composite foreign keys are in Future Improvements / not in doc/DESIGN.md | x |
| test/grant_public_api_return_types_test.ri | port | test/crud_test.ri | M1 | types of Court[db], where, order/limit/offset, to_a, first, find_by, find, count, exists?, new, create and reload; Collection, find_each, scalar, sole, import_records and WhereChain not in Ricord | x |
| test/grant_query_advanced_query_test.ri | defer |  |  | merge, dup of a query, where-chain operators (not_in, like, gt, between), subqueries and EXISTS are not built | |
| test/grant_query_aggregations_enumerable_test.ri | defer |  |  | aggregates (sum, avg, min, max, count(column), group counts) are not built | |
| test/grant_query_aggregations_typed_test.ri | defer |  |  | aggregates (count(column), distinct, sum, group counts) are not built | |
| test/grant_query_assemblers_pg_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_query_assemblers_sqlite_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_builder_test.ri | port | test/crud_test.ri | M1 | where, or_where, IN, IS NULL, raw where, order, limit and offset, checked by rows and SQL; where_fields introspection, where(:col, :op, value), and_where and raw or_where not in Ricord | x |
| test/grant_query_calculate_test.ri | defer |  |  | calculate and aggregates are not built | |
| test/grant_query_cte_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_distinct_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_query_excluding_invert_test.ri | defer |  |  | excluding/without and invert_where are not built | |
| test/grant_query_executor_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_existence_predicates_test.ri | port | test/crud_test.ri | M1 | exists?, empty? and any? as one LIMIT 1 probe with no ORDER BY, for no, one and many rows, a limit and an offset; none?, many?, one? and sole not built | x |
| test/grant_query_extract_associated_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_find_each_test.ri | port | test/each_test.ri | M4 |  | |
| test/grant_query_from_subquery_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_group_alias_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_grouped_aggregates_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_having_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_implicit_order_test.ri | port | test/crud_test.ri | M1 | plain reads unordered, first by id ascending, last by id descending (filtered too), an explicit order kept for first and last; find_each is M4; the implicit_order setting and implicit_order_column not built | x |
| test/grant_query_in_batches_relation_test.ri | port | test/each_test.ri | M4 |  | |
| test/grant_query_in_order_of_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_joins_integration_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_query_joins_nested_raw_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_query_joins_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_query_lazy_all_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_left_outer_joins_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_merge_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_modifiers_test.ri | defer |  |  | reorder, reverse_order, rewhere, reselect, regroup and none are not built | |
| test/grant_query_named_binds_test.ri | defer |  |  | named binds (:name) in raw conditions are not built | |
| test/grant_query_pluck_on_tape_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_query_query_parity_explain_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_query_parity_test.ri | defer |  |  | ids, unscope, association joins, annotate, find_each and update_all are not built | |
| test/grant_query_query_regressions_test.ri | port | test/crud_test.ri | M1 | Q-6 exclusive range end and Q-7 OR range grouped with AND (empty IN is in crud); Q-1..Q-5 and Q-8..Q-15 need pluck, ids, delete_all/update_all, where.not_in, nil in an IN list, raw bind arrays, subqueries, group, joins or batching | x |
| test/grant_query_relation_components_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_relation_load_test.ri | port | test/crud_test.ri | M1 | count bounded by limit/offset, empty?/any? as one LIMIT 1 probe, last; a Query is a value with no loaded state, so load/loaded?/records/reset/reload, memoized reads, size, many?/one?/none?, second, first(n)/last(n), none and where_in_place are not in Ricord | x |
| test/grant_query_rewhere_reorder_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_scoping_block_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_select_order_expressions_test.ri | defer |  |  | select expressions, group, raw ORDER BY expressions and NULLS FIRST/LAST are not in Ricord's query API (order takes column symbols only); its joined-column cases need joins (M4) | |
| test/grant_query_unscope_where_column_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_w6_merge_order_test.ri | defer |  |  | query feature not in v1 | |
| test/grant_query_w6_reorder_sql_test.ri | defer |  |  | reorder, reselect, regroup and reverse_order are not in Ricord's query API | |
| test/grant_query_where_nested_hash_test.ri | port | test/crud_test.ri | M4 | a nested hash on a joined table needs joins (M4); record values for a belongs_to need associations (M3) | |
| test/grant_query_where_not_or_and_not_test.ri | defer |  |  | where.not is not in Ricord's query API | |
| test/grant_query_where_not_or_and_relations_test.ri | defer |  |  | or/and of two queries is not in Ricord's query API; the keyword and string or_where forms are in test/crud_test.ri | |
| test/grant_query_where_not_or_and_test.ri | port | test/crud_test.ri | M4 | qualifying own columns against later joins needs joins (M4) | |
| test/grant_query_where_range_test.ri | port | test/crud_test.ri | M1 | closed, exclusive, beginless, endless and nil..nil ranges on Int64 and Float64 with where, or_where and chaining; Time and String ranges do not build (ris refuses a Range holding a tape type without @[OnTape]); ranges inside an array and where.between not in Ricord | x |
| test/grant_querying_all_test.ri | port | test/crud_test.ri | M1 | all, and a raw where for the Model.all(sql, binds) form | x |
| test/grant_querying_count_test.ri | port | test/crud_test.ri | M1 | Int64 counts, 0 for none, a value past Int32::MAX through db.scalar; grouped count needs group_by (not in Ricord); Result.integer_count is Grant-internal | x |
| test/grant_querying_enumerable_baseline_test.ri | port | test/crud_test.ri | M1 | to_a then Array methods, count, any?, first, exists?, chaining; each/map/reject on a query need batched each (M4); size is count | x |
| test/grant_querying_enumerable_test.ri | port | test/each_test.ri | M4 | a Query is not Enumerable: block forms of each/map/select/count/any? and the rest on a query need batched each (M4) | |
| test/grant_querying_exists_test.ri | port | test/crud_test.ri | M1 | exists? on where(id:), several keys and nil; exists?(id)/exists?(hash) shorthands, String primary keys and default_scope not in Ricord | x |
| test/grant_querying_find_by_test.ri | port | test/crud_test.ri | M1 | a string, several keys, nil, a keyword column name (backtick quoted); find_by_strict and hash arguments not in Ricord | x |
| test/grant_querying_find_each_test.ri | port | test/each_test.ri | M4 |  | |
| test/grant_querying_find_in_batches_test.ri | port | test/each_test.ri | M4 |  | |
| test/grant_querying_find_test.ri | port | test/crud_test.ri | M1 | find by id, persisted state, RecordNotFound (not nil) for a missing id; custom primary keys and namespaced models not in Ricord | x |
| test/grant_querying_first_test.ri | port | test/crud_test.ri | M1 | first by id, by an explicit order, nil for no row; the first(sql) and first_strict forms are order/where then first | x |
| test/grant_querying_from_rs_test.ri | defer |  |  | building a record from an arbitrary result set (named or reordered columns) is not in Ricord; read_row reads COLUMNS order only | |
| test/grant_querying_or_not_block_params_test.ri | port | test/crud_test.ri | M1 | OR of grouped AND conditions through or_where with several keys; the block forms of or_where and not are not in Ricord (no where.not) | x |
| test/grant_querying_passthrough_test.ri | port | test/crud_test.ri | M1 | db.query and db.scalar | x |
| test/grant_querying_query_builder_test.ri | port | test/crud_test.ri | M1 | IN on id, string, number and bool columns with where and or_where, exists? on where; and_where is where | x |
| test/grant_querying_relation_calculations_test.ri | defer |  |  | sum/avg/min/max are not in Ricord | |
| test/grant_querying_reload_test.ri | port | test/crud_test.ri | M1 | reload in place, unsaved changes dropped, RecordNotFound after destroy; changes/previous_changes are M2 | x |
| test/grant_querying_select_projection_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_sanitization_test.ri | defer |  |  | Ricord binds every value and has no quote/sanitize API | |
| test/grant_schema_advisory_lock_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_alter_table_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_check_unique_constraints_test.ri | port | test/schema_test.ri | M1 | check_constraint (named and unnamed) and a two-column unique index in create_table, enforced on both engines; adding or removing constraints on an existing table, introspection and PostgreSQL/MySQL forms not in Ricord | x |
| test/grant_schema_column_defaults_test.ri | port | test/schema_test.ri | M1 | string (quote escaped), integer and boolean literal defaults in the DDL and applied by the database; default_sql expressions and change_column_default not in Ricord | x |
| test/grant_schema_comments_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_composite_pk_create_test.ri | defer |  |  | composite primary keys are not in Ricord (column 0 is always the integer id); the PRIMARY KEY list DSL is migrations | |
| test/grant_schema_create_table_test.ri | port | test/schema_test.ri | M1 | the default INTEGER PRIMARY KEY AUTOINCREMENT id and IF NOT EXISTS (a second create_table keeps the rows); force, temporary, comments, collation, id types, tables without an id, drop_table and the PostgreSQL/MySQL forms are migrations, not in Ricord | x |
| test/grant_schema_ddl_transaction_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_environment_protection_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_foreign_keys_test.ri | port | test/schema_test.ri | M1 | REFERENCES with ON DELETE CASCADE, RESTRICT and SET NULL in create_table, a missing parent refused, cascade and nullify applied; add/remove/validate_foreign_key, on_update, deferrable, if_not_exists and introspection are migrations, not in Ricord | x |
| test/grant_schema_generator_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_indexes_test.ri | port | test/schema_test.ri | M1 | plain, unique and multi-column indexes with the default name or a given name, created with the table, the unique one enforced; partial, expression, using, order, include, concurrently, remove/rename_index and introspection are migrations, not in Ricord | x |
| test/grant_schema_introspection_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_m02a_review_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_micrate_sql_files_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_migration_context_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_migrator_options_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_model_indexes_test.ri | port | test/schema_test.ri | M1 | a model's unique index and a named two-column index (index name: added to the model macro) created by create_table, the unique one enforced | x |
| test/grant_schema_pending_check_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_pg_enum_extension_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_schema_references_join_table_test.ri | port | test/schema_test.ri | M1 | :references columns with a foreign key, on_delete, NOT NULL unless null: true; join tables (no id), polymorphic references, the automatic index on a reference and add/remove_reference are not in Ricord | x |
| test/grant_schema_rename_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_reversible_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_schema_cache_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_timestamps_ddl_test.ri | port | test/schema_test.ri | M1 | a datetime column NOT NULL unless null: true, a NULL insert refused; cols :timestamps is M2; precision and add/remove_timestamps are migrations | x |
| test/grant_schema_type_mapping_test.ri | port | test/schema_test.ri | M1 | the SQLite type of every Ricord column type and a round trip of each value; limit is accepted but not emitted; decimal, date, uuid, smallint and the PostgreSQL/MySQL catalogs are not in Ricord | x |
| test/grant_schema_verify_model_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_w6b_add_timestamps_sqlite_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_w6b_change_column_default_sqlite_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_w6b_execute_schema_qualified_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_w6b_internal_metadata_wired_test.ri | defer |  |  | migrations and schema tooling are in Future Improvements | |
| test/grant_schema_w6b_mysql_live_test.ri | drop |  |  | PostgreSQL or MySQL only | |
| test/grant_scoping_default_scope_everywhere_test.ri | defer |  |  | default and named scopes are not in v1 (scope comes from associations) | |
| test/grant_scoping_named_scope_chaining_test.ri | defer |  |  | default and named scopes are not in v1 (scope comes from associations) | |
| test/grant_scoping_scoping_test.ri | defer |  |  | default and named scopes are not in v1 (scope comes from associations) | |
| test/grant_secure_token_test.ri | defer |  |  | attribute API extras are not in v1 | |
| test/grant_select_select_test.ri | port | test/pluck_test.ri | M4 |  | |
| test/grant_simple_connection_test.ri | port | test/crud_test.ri | M1 | a second Ricord.open on the same URI sees committed rows; the connection registry and roles are replaced by Ricord.open and the URI | x |
| test/grant_spec_support_transactional_wrapper_test.ri | port | test/crud_test.ri | M1 | rows made in a rolled-back write, nested ones too, are gone (with_db gives each test a fresh file, so no wrapper is needed); after_commit in the wrapper is M2; several connections and the timing check are Grant-only | x |
| test/grant_table_table_test.ri | port | test/schema_test.ri | M1 | the table name from table or the model name (pluralized), the primary key id; custom primary keys and namespaced models are not in Ricord | x |
| test/grant_tape_model_test.ri | port | test/crud_test.ri | M1 | typed reads, to_param, a copy is the same record, every where form, order/limit/first, find_by, exists?, an unchanged chained query, a rolled-back write and destroy; validations, callbacks, dirty tracking and timestamps are M2, associations M3, pluck, includes, delete_all and update_all M4; to_json and heap copies are not in Ricord | x |
| test/grant_tasks_seeds_test.ri | drop |  |  | rake-style tasks and fixtures removed | |
| test/grant_tasks_truncate_all_test.ri | drop |  |  | rake-style tasks and fixtures removed | |
| test/grant_test_fixtures_test.ri | drop |  |  | rake-style tasks and fixtures removed | |
| test/grant_transaction_after_all_commit_test.ri | defer |  |  | after_all_transactions_commit and current_transaction.after_commit (closures queued on the write) are not in doc/DESIGN.md: the queue holds flat items from model callbacks only | |
| test/grant_transaction_atomicity_test.ri | port | test/write_test.ri | M1 | a failure or a Rollback undoes every row, a clean block keeps them, rows of several models roll back together; routing per adapter is Grant-only | x |
| test/grant_transaction_cross_database_nesting_test.ri | drop |  |  | transaction routing and options replaced by db.write | |
| test/grant_transaction_error_translation_test.ri | port | test/write_test.ri | M1 | a failing statement in a savepoint is a DatabaseError and the outer work commits; a constraint failure from COMMIT itself is returned and the session keeps working; read-only and serializable transactions are PostgreSQL only | x |
| test/grant_transaction_handle_test.ri | drop |  |  | transaction routing and options replaced by db.write | |
| test/grant_transaction_isolation_sql_test.ri | drop |  |  | transaction routing and options replaced by db.write | |
| test/grant_transaction_joinable_test.ri | drop |  |  | transaction routing and options replaced by db.write | |
| test/grant_transaction_replica_routing_test.ri | drop |  |  | transaction routing and options replaced by db.write | |
| test/grant_transaction_requires_new_savepoint_test.ri | drop |  |  | transaction routing and options replaced by db.write | |
| test/grant_transaction_return_value_test.ri | port | test/write_test.ri | M1 | write returns the block value (a record, Int32, String, nil), a nested write's value, the Rollback or the failure itself; joinable/independent levels and Grant.transaction forms are replaced by db.write | x |
| test/grant_transaction_savepoint_failure_test.ri | port | test/write_test.ri | M1 | a failing savepoint rolls back alone, a failing statement is recovered with ROLLBACK TO and COMMIT follows, no write is left open, savepoint names stay unique; savepoint callbacks are M2; restoring a record's in-memory state after a rolled-back savepoint is not in Ricord | x |
| test/grant_transaction_test.ri | port | test/write_test.ri | M1 | commit, rollback on a failure and on Rollback, a nested write as a savepoint, a released savepoint undone with the outer write, whether a write is open (state.depth); a joined nested block is not in Ricord (every nested write is a savepoint); isolation levels and readonly are PostgreSQL/MySQL options | x |
| test/grant_transactions_create_test.ri | port | test/write_test.ri | M1 | create persists and reads back (the reserved word column is in crud_test); validations and skip_timestamps are M2; custom primary keys and namespaced models are not in Ricord | x |
| test/grant_transactions_destroy_test.ri | port | test/write_test.ri | M1 | destroy removes the row and moves destroyed? and persisted?; a before_destroy abort is M2; custom primary keys and namespaced models are not in Ricord | x |
| test/grant_transactions_import_test.ri | port | test/write_test.ri | M4 | import_records is a bulk write (M4); upserts on a non-auto key need settable primary keys, not in Ricord | |
| test/grant_transactions_save_natural_key_test.ri | defer |  |  | String (natural) primary keys are not in Ricord (column 0 is always the integer id) | |
| test/grant_transactions_save_test.ri | port | test/write_test.ri | M1 | save inserts then updates, new_record? and persisted? move; validations, type conversion errors and skip_timestamps are M2; a new record with another's id needs a settable id, not in Ricord | x |
| test/grant_transactions_timestamp_precision_test.ri | port | test/dirty_test.ri | M2 | assigned stamps with microseconds are kept by a create and read back equal, a later changing save moves updated_at with subsecond precision; set_timestamps and save(skip_timestamps:) become assigning the columns, touch is not in doc/DESIGN.md | x |
| test/grant_transactions_touch_test.ri | defer |  |  | touch (with named columns and its errors) is not in doc/DESIGN.md; updated_at moving on a changing save is in dirty_test | |
| test/grant_transactions_update_test.ri | port | test/write_test.ri | M1 | a setter and save update a row, nil saved into a nullable column; update(**attrs), validations and timestamps are M2 | x |
| test/grant_validation_helpers_blank_test.ri | port | test/validation_test.ri | M2 | not-blank as presence: empty and whitespace-only text fail; is_blank (absence) and Grant's "must not be blank" wording are not in doc/DESIGN.md (Rails message "can't be blank") | x |
| test/grant_validation_helpers_choice_test.ri | port | test/validation_test.ri | M2 | inclusion over a String list and an integer list; the message is Rails' "is not included in the list", not Grant's choice list; Symbol choices are not in Ricord | x |
| test/grant_validation_helpers_exclusion_test.ri | defer |  |  | needs an exclusion validator, not in doc/DESIGN.md | |
| test/grant_validation_helpers_inequality_test.ri | defer |  |  | needs a numericality (less/greater than) validator, not in doc/DESIGN.md | |
| test/grant_validation_helpers_lenght_test.ri | port | test/validation_test.ri | M2 | minimum and maximum with Rails messages, both boundaries allowed; Grant's wording and its nil panic are not kept (nil counts as "") | x |
| test/grant_validation_helpers_nil_test.ri | port | test/validation_test.ri | M2 | not-nil as presence on integer and boolean columns (nil fails, zero present, false blank as in Rails); is_nil and Grant's wording are not in doc/DESIGN.md | x |
| test/grant_validation_helpers_uniqueness_test.ri | defer |  |  | needs a uniqueness validator, not in doc/DESIGN.md (a unique index refuses with DatabaseError, tested in crud_test) | |
| test/grant_validations_condition_arrays_test.ri | defer |  |  | needs if:/unless: conditions on validations and callbacks, not in doc/DESIGN.md | |
| test/grant_validations_error_object_test.ri | port | test/validation_test.ri | M2 | humanized full messages ("First name", an _id suffix dropped, :base alone); typed entries, options, match?, copy and i18n names are not in doc/DESIGN.md | x |
| test/grant_validations_errors_api_test.ri | defer |  |  | needs typed error entries with options (of_type, where, added?, delete, details, as_json, merge, import), not in doc/DESIGN.md; the plain full message is covered by grant_validations_error_object | |
| test/grant_validations_errors_details_options_test.ri | defer |  |  | needs errors.details (typed entries with count/value options), not in doc/DESIGN.md | |
| test/grant_validations_multi_attribute_test.ri | port | test/validation_test.ri | M2 | one validates line over several columns (presence, length); numericality, exclusion, absence, comparison, confirmation, acceptance, email, url and allow_nil are not in doc/DESIGN.md | x |
| test/grant_validations_presence_blank_test.ri | port | test/validation_test.ri | M2 | nil, false and whitespace-only text are blank, zero present; collection-typed properties are not Ricord columns; allow_blank and on: contexts are not in doc/DESIGN.md | x |
| test/grant_validations_validate_bang_test.ri | port | test/validation_test.ri | M2 | an invalid save returns RecordInvalid with the full message and the entries stay on the record (Ricord has no validate! — save returns the error); on: contexts are not in doc/DESIGN.md | x |
| test/grant_validations_validator_info_evaluation_test.ri | defer |  |  | needs validator reflection (validators_on), not in doc/DESIGN.md | |
| test/grant_validations_validator_test.ri | port | test/validation_test.ri | M2 | a custom check on one column and a record-level check, a fixed record validates again; the proc and block forms become validate :method | x |
| test/grant_validations_w6_presence_message_test.ri | defer |  |  | needs message: options (String, Symbol key, Proc), i18n, allow_blank, if: and on:, not in doc/DESIGN.md; an invalid save writing nothing is covered by validation_test | |
| test/grant_validators_built_in_test.ri | port | test/validation_test.ri | M2 | length minimum/maximum/is, format with:, inclusion, every validator's entry collected; numericality, format without:, email, url, length in:, confirmation, acceptance, exclusion, validates_associated, message: and if: are not in doc/DESIGN.md | x |
| test/grant_validators_contexts_test.ri | defer |  |  | needs on: validation contexts, not in doc/DESIGN.md | |
| test/grant_validators_parity_test.ri | port | test/validation_test.ri | M2 | validate :method adding an entry or none; validates_with, validates_each, comparison, absence, invalid?, details, on: and if:/unless: are not in doc/DESIGN.md | x |
| test/grant_validators_presence_test.ri | port | test/validation_test.ri | M2 | nil, empty and whitespace text fail with "can't be blank", nil on a non-text column fails, every failure collected; message: and if:/unless: are not in doc/DESIGN.md | x |
| test/grant_validators_uniqueness_test.ri | defer |  |  | needs a uniqueness validator (with scope and case_sensitive), not in doc/DESIGN.md | |
| test/hash_equality.ri | drop |  |  | support file, not a test | |
| test/integration_mixed_adapter_test.ri | drop |  |  | adapter and config layer replaced by Ricord.open and the URI scheme | |
| test/ivar_initializer_save_probe.ri | drop |  |  | support file, not a test | |
| test/m03_fixture.ri | drop |  |  | support file, not a test | |
| test/m04_tasks_fixture.ri | drop |  |  | support file, not a test | |
| test/nation.ri | drop |  |  | support file, not a test | |
| test/pool_spec_support.ri | drop |  |  | support file, not a test | |
| test/query_relation_sql_capture.ri | drop |  |  | support file, not a test | |
| test/query_spec_helper.ri | drop |  |  | support file, not a test | |
| test/querying_spec_models.ri | drop |  |  | support file, not a test | |
| test/schema_fixture.ri | drop |  |  | support file, not a test | |
| test/spec_helper.ri | drop |  |  | support file, not a test | |
| test/spike_crud_test.ri | port | test/crud_test.ri | M1 | create, save, find, where, destroy, destroyed? and RecordNotFound after it; the after_destroy callback is M2 | x |
| test/table_namespace_model.ri | drop |  |  | support file, not a test | |
| test/transaction_crud_models.ri | drop |  |  | support file, not a test | |
| test/transaction_sql_recorder.ri | drop |  |  | support file, not a test | |
| test/v02_reflection_evaluation_counter.ri | drop |  |  | support file, not a test | |
| test/validation_details_support.ri | drop |  |  | support file, not a test | |
| test/w6_c04_support.ri | drop |  |  | support file, not a test | |
| test/where_family_models.ri | drop |  |  | support file, not a test | |
| test/write_sql_capture.ri | drop |  |  | support file, not a test | |
