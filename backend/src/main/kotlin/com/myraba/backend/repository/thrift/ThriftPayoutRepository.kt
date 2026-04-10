// 4. ThriftPayoutRepository.kt
package com.myraba.backend.repository.thrift

import com.myraba.backend.model.thrift.ThriftPayout
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface ThriftPayoutRepository : JpaRepository<ThriftPayout, Long>