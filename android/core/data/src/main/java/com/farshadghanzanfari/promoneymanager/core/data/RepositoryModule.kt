package com.farshadghanzanfari.promoneymanager.core.data

import com.farshadghanzanfari.promoneymanager.core.domain.WorkspaceRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {
    @Binds
    @Singleton
    abstract fun workspace(implementation: RoomWorkspaceRepository): WorkspaceRepository

    @Binds
    @Singleton
    abstract fun settings(implementation: SettingsDataStore): SettingsStore
}
