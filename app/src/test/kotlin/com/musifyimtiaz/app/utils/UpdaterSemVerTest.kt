package com.musifyimtiaz.app.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdaterSemVerTest {
    @Test
    fun findLatestRelease_picksHighestStableSemverEvenIfNotFirst() {
        val releases =
            listOf(
                ReleaseInfo(
                    tagName = "v12.4.7",
                    name = "12.4.7",
                    body = null,
                    publishedAt = "2026-01-01T00:00:00Z",
                    htmlUrl = "https://example.com/12.4.7",
                ),
                ReleaseInfo(
                    tagName = "v13.0.0",
                    name = "13.0.0",
                    body = null,
                    publishedAt = "2026-02-01T00:00:00Z",
                    htmlUrl = "https://example.com/13.0.0",
                ),
            )

        val latest = Updater.findLatestRelease(releases)
        assertNotNull(latest)
        assertEquals("v13.0.0", latest?.tagName)
    }

    @Test
    fun findLatestRelease_ignoresPrereleaseWhenStableExists() {
        val releases =
            listOf(
                ReleaseInfo(
                    tagName = "v13.0.0-beta.1",
                    name = "13.0.0-beta.1",
                    body = null,
                    publishedAt = "2026-02-01T00:00:00Z",
                    htmlUrl = "https://example.com/13.0.0-beta.1",
                ),
                ReleaseInfo(
                    tagName = "v12.4.7",
                    name = "12.4.7",
                    body = null,
                    publishedAt = "2026-01-01T00:00:00Z",
                    htmlUrl = "https://example.com/12.4.7",
                ),
            )

        val latest = Updater.findLatestRelease(releases)
        assertNotNull(latest)
        assertEquals("v12.4.7", latest?.tagName)
    }

    @Test
    fun isSameVersion_matchesSemverRegardlessOfPrefixOrText() {
        assertTrue(Updater.isSameVersion("v13.0.0", "13.0.0"))
        assertTrue(Updater.isSameVersion("Musify 13.0.0", "13.0.0"))
        assertFalse(Updater.isSameVersion("13.0.1", "13.0.0"))
    }

    @Test
    fun isUpdateAvailable_onlyReturnsTrueWhenLatestIsNewer() {
        assertTrue(
            Updater.isUpdateAvailable(
                currentVersionName = "3.0.0",
                latestVersionName = "v3.0.1",
            )
        )
        assertFalse(
            Updater.isUpdateAvailable(
                currentVersionName = "3.0.1",
                latestVersionName = "3.0.1",
            )
        )
        assertFalse(
            Updater.isUpdateAvailable(
                currentVersionName = "3.1.0",
                latestVersionName = "3.0.9",
            )
        )
    }

    @Test
    fun latestDownloadUrl_usesStableAssetName() {
        assertTrue(Updater.getLatestDownloadUrl().endsWith("/latest/download/app-release.apk"))
    }
}
