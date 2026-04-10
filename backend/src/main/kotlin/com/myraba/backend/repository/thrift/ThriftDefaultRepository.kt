package com.myraba.backend.repository.thrift

import com.myraba.backend.model.User
import com.myraba.backend.model.thrift.DefaultStatus
import com.myraba.backend.model.thrift.ThriftDefault
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.math.BigDecimal

@Repository
interface ThriftDefaultRepository : JpaRepository<ThriftDefault, Long> {
    fun findByDefaulter(defaulter: User): List<ThriftDefault>
    fun findByDefaulterAndStatus(defaulter: User, status: DefaultStatus): List<ThriftDefault>
    fun findByStatus(status: DefaultStatus): List<ThriftDefault>
    fun existsByDefaulterAndStatusIn(defaulter: User, statuses: List<DefaultStatus>): Boolean
}
