from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
BOOTSTRAP = ROOT / "tools" / "memory" / "bootstrap" / "memory_v1_canonical.sql"


class CanonicalBootstrapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sql = BOOTSTRAP.read_text(encoding="utf-8")
        cls.memory_records = cls.sql.split(
            "CREATE TABLE mimir.memory_records (", 1
        )[1].split(
            "CREATE TABLE mimir.memory_relations (", 1
        )[0]

    def test_bootstrap_is_explicitly_reconstruction(self):
        self.assertIn(
            "This is NOT the recovered historical migration 001.",
            self.sql,
        )
        self.assertIn(
            "'Estrutura temporal inicial da memória do Mimir'",
            self.sql,
        )

    def test_bootstrap_refuses_noncanonical_database(self):
        self.assertIn(
            "current_database() <> 'mimir_memory'",
            self.sql,
        )
        self.assertIn(
            "requires an empty database without schema mimir",
            self.sql,
        )

    def test_base_tables_are_present(self):
        for table in (
            "schema_version",
            "memory_events",
            "memory_records",
            "memory_relations",
            "memory_audit",
        ):
            with self.subTest(table=table):
                self.assertIn(
                    f"CREATE TABLE mimir.{table}",
                    self.sql,
                )

    def test_post_v1_tables_are_absent(self):
        for table in (
            "memory_reviews",
            "reviewer_identities",
            "session_sources",
        ):
            with self.subTest(table=table):
                self.assertNotIn(
                    f"CREATE TABLE mimir.{table}",
                    self.sql,
                )

    def test_post_v1_indexes_are_absent(self):
        for index in (
            "memory_events_source_hash_uq",
            "memory_records_source_key_hash_uq",
            "memory_records_active_key_uq",
            "memory_events_openclaw_session_uq",
        ):
            with self.subTest(index=index):
                self.assertNotIn(
                    f"CREATE INDEX {index}",
                    self.sql,
                )
                self.assertNotIn(
                    f"CREATE UNIQUE INDEX {index}",
                    self.sql,
                )

    def test_base_indexes_are_present(self):
        for index in (
            "memory_events_scope_time_idx",
            "memory_events_type_time_idx",
            "memory_records_key_idx",
            "memory_records_scope_status_idx",
            "memory_records_search_gin_idx",
            "memory_records_source_event_idx",
            "memory_records_type_idx",
            "memory_relations_from_idx",
            "memory_relations_to_idx",
        ):
            with self.subTest(index=index):
                self.assertIn(index, self.sql)

    def test_memory_records_has_v1_generated_search_but_not_v3_hash(self):
        self.assertIn(
            "search_document    tsvector GENERATED ALWAYS AS",
            self.memory_records,
        )
        self.assertNotIn(
            "content_sha256",
            self.memory_records,
        )

    def test_base_types_match_observed_schema(self):
        for fragment in (
            "confidence         numeric(4,3)",
            "importance         numeric(4,3)",
            "decay_rate         numeric(6,5)",
            "embedding          public.vector(768)",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.memory_records)

    def test_baseline_privileges_support_later_revocations(self):
        self.assertIn(
            "GRANT SELECT",
            self.sql,
        )
        self.assertIn(
            "GRANT INSERT",
            self.sql,
        )
        self.assertNotIn(
            "GRANT UPDATE",
            self.sql,
        )
        self.assertNotIn(
            "GRANT DELETE",
            self.sql,
        )


if __name__ == "__main__":
    unittest.main()
