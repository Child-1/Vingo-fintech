// 5. ThriftPenaltyRepository.kt
package com.myraba.backend.repository.thrift

import com.myraba.backend.model.thrift.ThriftPenalty
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface ThriftPenaltyRepository : JpaRepository<ThriftPenalty, Long>