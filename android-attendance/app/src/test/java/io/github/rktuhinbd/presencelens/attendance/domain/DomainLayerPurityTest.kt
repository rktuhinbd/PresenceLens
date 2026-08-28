package io.github.rktuhinbd.presencelens.attendance.domain

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * `android-attendance/AGENTS.md`: *"`domain` has zero Android imports."*
 *
 * That rule is what makes the 50 m rule, the freshness bound, the accuracy policy, and the
 * office-capture use case testable with plain JUnit - no emulator, no Robolectric, no Play
 * Services. It is also the rule most likely to be broken by a single convenient import that
 * nobody notices, because nothing else in the build would fail.
 *
 * So it is asserted rather than trusted. This reads the domain sources as text, which is
 * unusual for a unit test and is the point: the guarantee is about the *source*, and no
 * runtime assertion can express it.
 */
class DomainLayerPurityTest {

    @Test
    fun `no domain source imports Android or Play Services`() {
        val offenders = domainSources()
            .flatMap { file ->
                file.readLines()
                    .map(String::trim)
                    .filter { line -> FORBIDDEN_IMPORTS.any(line::startsWith) }
                    .map { line -> "${file.name}: $line" }
            }

        assertTrue(
            "the domain layer must not depend on Android:\n${offenders.joinToString("\n")}",
            offenders.isEmpty()
        )
    }

    @Test
    fun `the domain layer is actually being scanned`() {
        // Without this, a wrong working directory would turn the test above into a test that
        // always passes - the worst possible failure mode for an architecture guard.
        assertTrue(domainSources().size >= EXPECTED_MINIMUM_SOURCES)
    }

    private fun domainSources(): List<File> = DOMAIN_SOURCE_CANDIDATES
        .map(::File)
        .firstOrNull(File::isDirectory)
        ?.walkTopDown()
        ?.filter { it.isFile && it.extension == "kt" }
        ?.toList()
        ?: error(
            "domain sources not found; looked in ${DOMAIN_SOURCE_CANDIDATES.joinToString()} " +
                "from ${File("").absolutePath}"
        )

    private companion object {
        const val DOMAIN_PACKAGE_PATH =
            "src/main/java/io/github/rktuhinbd/presencelens/attendance/domain"

        /** Gradle runs unit tests from the module directory; the others are belt and braces. */
        val DOMAIN_SOURCE_CANDIDATES = listOf(
            DOMAIN_PACKAGE_PATH,
            "app/$DOMAIN_PACKAGE_PATH",
            "android-attendance/app/$DOMAIN_PACKAGE_PATH"
        )

        val FORBIDDEN_IMPORTS = listOf(
            "import android.",
            "import androidx.",
            "import com.google.android."
        )

        /** Low enough to survive refactoring, high enough that an empty scan cannot pass. */
        const val EXPECTED_MINIMUM_SOURCES = 10
    }
}
