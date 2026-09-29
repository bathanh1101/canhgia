export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      admin_audit_log: {
        Row: {
          action: string
          admin_id: string | null
          created_at: string
          detail: Json
          id: number
          target: string | null
        }
        Insert: {
          action: string
          admin_id?: string | null
          created_at?: string
          detail?: Json
          id?: never
          target?: string | null
        }
        Update: {
          action?: string
          admin_id?: string | null
          created_at?: string
          detail?: Json
          id?: never
          target?: string | null
        }
        Relationships: []
      }
      admins: {
        Row: {
          created_at: string
          created_by: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admins_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      app_settings: {
        Row: {
          key: string
          value: Json | null
        }
        Insert: {
          key: string
          value?: Json | null
        }
        Update: {
          key?: string
          value?: Json | null
        }
        Relationships: []
      }
      at_rate_bucket: {
        Row: {
          bucket: string
          capacity: number
          refill_per_min: number
          refilled_at: string
          tokens: number
        }
        Insert: {
          bucket: string
          capacity: number
          refill_per_min: number
          refilled_at?: string
          tokens: number
        }
        Update: {
          bucket?: string
          capacity?: number
          refill_per_min?: number
          refilled_at?: string
          tokens?: number
        }
        Relationships: []
      }
      bank_accounts: {
        Row: {
          account_name: string
          account_name_norm: string
          account_number: string
          bank_bin: string
          created_at: string
          holder_name_verified: boolean
          id: string
          is_default: boolean
          user_id: string
        }
        Insert: {
          account_name: string
          account_name_norm: string
          account_number: string
          bank_bin: string
          created_at?: string
          holder_name_verified?: boolean
          id?: string
          is_default?: boolean
          user_id: string
        }
        Update: {
          account_name?: string
          account_name_norm?: string
          account_number?: string
          bank_bin?: string
          created_at?: string
          holder_name_verified?: boolean
          id?: string
          is_default?: boolean
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bank_accounts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      banks: {
        Row: {
          bin: string
          code: string
          is_enabled: boolean
          name: string
          sort: number
        }
        Insert: {
          bin: string
          code: string
          is_enabled?: boolean
          name: string
          sort?: number
        }
        Update: {
          bin?: string
          code?: string
          is_enabled?: boolean
          name?: string
          sort?: number
        }
        Relationships: []
      }
      campaign_commissions: {
        Row: {
          category_key: string
          commission_rate_bps: number
          merchant_id: string
          updated_at: string
        }
        Insert: {
          category_key?: string
          commission_rate_bps: number
          merchant_id: string
          updated_at?: string
        }
        Update: {
          category_key?: string
          commission_rate_bps?: number
          merchant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "campaign_commissions_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
        ]
      }
      cashback_rules: {
        Row: {
          category_key: string | null
          id: number
          merchant_id: string | null
          user_share_bps: number
        }
        Insert: {
          category_key?: string | null
          id?: never
          merchant_id?: string | null
          user_share_bps: number
        }
        Update: {
          category_key?: string | null
          id?: never
          merchant_id?: string | null
          user_share_bps?: number
        }
        Relationships: [
          {
            foreignKeyName: "cashback_rules_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
        ]
      }
      clicks: {
        Row: {
          aff_link: string | null
          created_at: string
          device_hash: string | null
          id: number
          merchant_id: string
          offer_id: number | null
          origin_url: string | null
          resolved_url: string | null
          shared_at: string | null
          short_link: string | null
          source: Database["public"]["Enums"]["click_source"]
          status: Database["public"]["Enums"]["click_status"]
          user_id: string
          utm_content: string | null
        }
        Insert: {
          aff_link?: string | null
          created_at?: string
          device_hash?: string | null
          id?: never
          merchant_id: string
          offer_id?: number | null
          origin_url?: string | null
          resolved_url?: string | null
          shared_at?: string | null
          short_link?: string | null
          source?: Database["public"]["Enums"]["click_source"]
          status?: Database["public"]["Enums"]["click_status"]
          user_id: string
          utm_content?: string | null
        }
        Update: {
          aff_link?: string | null
          created_at?: string
          device_hash?: string | null
          id?: never
          merchant_id?: string
          offer_id?: number | null
          origin_url?: string | null
          resolved_url?: string | null
          shared_at?: string | null
          short_link?: string | null
          source?: Database["public"]["Enums"]["click_source"]
          status?: Database["public"]["Enums"]["click_status"]
          user_id?: string
          utm_content?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "clicks_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "clicks_offer_id_fkey"
            columns: ["offer_id"]
            isOneToOne: false
            referencedRelation: "offers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "clicks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      coin_ledger: {
        Row: {
          amount: number
          created_at: string
          id: number
          idempotency_key: string
          reason: string
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: never
          idempotency_key: string
          reason: string
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: never
          idempotency_key?: string
          reason?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "coin_ledger_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      daily_checkins: {
        Row: {
          coins: number
          day: string
          streak: number
          user_id: string
        }
        Insert: {
          coins: number
          day: string
          streak: number
          user_id: string
        }
        Update: {
          coins?: number
          day?: string
          streak?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "daily_checkins_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      extension_login_codes: {
        Row: {
          code: string
          created_at: string
          expires_at: string
          requester_ip: unknown
          secret_hash: string
          status: string
          user_agent: string | null
          user_id: string | null
        }
        Insert: {
          code?: string
          created_at?: string
          expires_at?: string
          requester_ip?: unknown
          secret_hash: string
          status?: string
          user_agent?: string | null
          user_id?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          expires_at?: string
          requester_ip?: unknown
          secret_hash?: string
          status?: string
          user_agent?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "extension_login_codes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fraud_flags: {
        Row: {
          created_at: string
          dedupe_key: string
          evidence: Json
          id: number
          resolved_at: string | null
          resolved_by: string | null
          score: number
          status: Database["public"]["Enums"]["flag_status"]
          type: Database["public"]["Enums"]["fraud_type"]
          user_id: string | null
        }
        Insert: {
          created_at?: string
          dedupe_key: string
          evidence?: Json
          id?: never
          resolved_at?: string | null
          resolved_by?: string | null
          score?: number
          status?: Database["public"]["Enums"]["flag_status"]
          type: Database["public"]["Enums"]["fraud_type"]
          user_id?: string | null
        }
        Update: {
          created_at?: string
          dedupe_key?: string
          evidence?: Json
          id?: never
          resolved_at?: string | null
          resolved_by?: string | null
          score?: number
          status?: Database["public"]["Enums"]["flag_status"]
          type?: Database["public"]["Enums"]["fraud_type"]
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fraud_flags_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      kyc_profiles: {
        Row: {
          back_path: string
          front_path: string
          full_name: string
          full_name_norm: string
          id_number_hmac: string
          id_number_last4: string
          reject_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: Database["public"]["Enums"]["kyc_status"]
          submitted_at: string
          user_id: string
        }
        Insert: {
          back_path: string
          front_path: string
          full_name: string
          full_name_norm: string
          id_number_hmac: string
          id_number_last4: string
          reject_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["kyc_status"]
          submitted_at?: string
          user_id: string
        }
        Update: {
          back_path?: string
          front_path?: string
          full_name?: string
          full_name_norm?: string
          id_number_hmac?: string
          id_number_last4?: string
          reject_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: Database["public"]["Enums"]["kyc_status"]
          submitted_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "kyc_profiles_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      merchants: {
        Row: {
          activation_hours: number
          at_campaign_id: string | null
          badge_letter: string | null
          datafeed_enabled: boolean
          domains: string[]
          extension_enabled: boolean
          hold_days: number
          id: string
          is_active: boolean
          link_api: string
          max_user_rate_bps: number | null
          name: string
          sort: number
        }
        Insert: {
          activation_hours?: number
          at_campaign_id?: string | null
          badge_letter?: string | null
          datafeed_enabled?: boolean
          domains?: string[]
          extension_enabled?: boolean
          hold_days?: number
          id: string
          is_active?: boolean
          link_api?: string
          max_user_rate_bps?: number | null
          name: string
          sort?: number
        }
        Update: {
          activation_hours?: number
          at_campaign_id?: string | null
          badge_letter?: string | null
          datafeed_enabled?: boolean
          domains?: string[]
          extension_enabled?: boolean
          hold_days?: number
          id?: string
          is_active?: boolean
          link_api?: string
          max_user_rate_bps?: number | null
          name?: string
          sort?: number
        }
        Relationships: []
      }
      missing_order_reports: {
        Row: {
          admin_note: string | null
          created_at: string
          first_approved_amount: number | null
          first_approved_at: string | null
          first_approved_by: string | null
          id: number
          image_paths: string[]
          merchant_id: string
          order_code: string
          order_code_norm: string | null
          order_value_vnd: number
          public_code: string
          purchased_on: string
          resolution_amount_vnd: number | null
          resolved_at: string | null
          resolved_order_id: string | null
          status: string
          user_id: string
        }
        Insert: {
          admin_note?: string | null
          created_at?: string
          first_approved_amount?: number | null
          first_approved_at?: string | null
          first_approved_by?: string | null
          id?: never
          image_paths?: string[]
          merchant_id: string
          order_code: string
          order_code_norm?: string | null
          order_value_vnd: number
          public_code?: string
          purchased_on: string
          resolution_amount_vnd?: number | null
          resolved_at?: string | null
          resolved_order_id?: string | null
          status?: string
          user_id: string
        }
        Update: {
          admin_note?: string | null
          created_at?: string
          first_approved_amount?: number | null
          first_approved_at?: string | null
          first_approved_by?: string | null
          id?: never
          image_paths?: string[]
          merchant_id?: string
          order_code?: string
          order_code_norm?: string | null
          order_value_vnd?: number
          public_code?: string
          purchased_on?: string
          resolution_amount_vnd?: number | null
          resolved_at?: string | null
          resolved_order_id?: string | null
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "missing_order_reports_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "missing_order_reports_resolved_order_id_fkey"
            columns: ["resolved_order_id"]
            isOneToOne: false
            referencedRelation: "admin_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "missing_order_reports_resolved_order_id_fkey"
            columns: ["resolved_order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "missing_order_reports_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      mission_claims: {
        Row: {
          claimed_at: string
          code: string
          reward_amount: number
          user_id: string
          week_start: string
        }
        Insert: {
          claimed_at?: string
          code: string
          reward_amount: number
          user_id: string
          week_start: string
        }
        Update: {
          claimed_at?: string
          code?: string
          reward_amount?: number
          user_id?: string
          week_start?: string
        }
        Relationships: [
          {
            foreignKeyName: "mission_claims_code_fkey"
            columns: ["code"]
            isOneToOne: false
            referencedRelation: "missions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "mission_claims_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      missions: {
        Row: {
          code: string
          is_active: boolean
          kind: string
          reward_amount: number
          reward_kind: string
          sort: number
          target: number
          title: string
        }
        Insert: {
          code: string
          is_active?: boolean
          kind: string
          reward_amount: number
          reward_kind: string
          sort?: number
          target: number
          title: string
        }
        Update: {
          code?: string
          is_active?: boolean
          kind?: string
          reward_amount?: number
          reward_kind?: string
          sort?: number
          target?: number
          title?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          body: string | null
          created_at: string
          data: Json
          id: number
          push_attempts: number
          push_claimed_at: string | null
          push_sent_at: string | null
          read_at: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Insert: {
          body?: string | null
          created_at?: string
          data?: Json
          id?: never
          push_attempts?: number
          push_claimed_at?: string | null
          push_sent_at?: string | null
          read_at?: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Update: {
          body?: string | null
          created_at?: string
          data?: Json
          id?: never
          push_attempts?: number
          push_claimed_at?: string | null
          push_sent_at?: string | null
          read_at?: string | null
          title?: string
          type?: Database["public"]["Enums"]["notification_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      offers: {
        Row: {
          brand: string | null
          cashback_eligible: boolean
          category_key: string | null
          external_product_id: string
          fts: unknown
          id: number
          image_url: string | null
          list_price: number | null
          merchant_id: string
          name: string
          name_norm: string | null
          price: number | null
          product_group_id: number | null
          shop_name: string | null
          sku: string | null
          updated_at: string
          url: string | null
        }
        Insert: {
          brand?: string | null
          cashback_eligible?: boolean
          category_key?: string | null
          external_product_id: string
          fts?: unknown
          id?: never
          image_url?: string | null
          list_price?: number | null
          merchant_id: string
          name: string
          name_norm?: string | null
          price?: number | null
          product_group_id?: number | null
          shop_name?: string | null
          sku?: string | null
          updated_at?: string
          url?: string | null
        }
        Update: {
          brand?: string | null
          cashback_eligible?: boolean
          category_key?: string | null
          external_product_id?: string
          fts?: unknown
          id?: never
          image_url?: string | null
          list_price?: number | null
          merchant_id?: string
          name?: string
          name_norm?: string | null
          price?: number | null
          product_group_id?: number | null
          shop_name?: string | null
          sku?: string | null
          updated_at?: string
          url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "offers_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "offers_product_group_id_fkey"
            columns: ["product_group_id"]
            isOneToOne: false
            referencedRelation: "product_groups"
            referencedColumns: ["id"]
          },
        ]
      }
      order_raw: {
        Row: {
          order_id: string
          raw: Json
        }
        Insert: {
          order_id: string
          raw: Json
        }
        Update: {
          order_id?: string
          raw?: Json
        }
        Relationships: [
          {
            foreignKeyName: "order_raw_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: true
            referencedRelation: "admin_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_raw_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: true
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          at_status: number | null
          category_key: string | null
          click_id: number | null
          click_time: string | null
          commission_vnd: number
          confirmed_time: string | null
          conversion_id: number | null
          created_at: string
          credit_state: Database["public"]["Enums"]["credit_state"]
          id: string
          is_confirmed: number
          matched_by: string | null
          merchant_id: string
          order_time: string | null
          product_id: string | null
          product_name: string | null
          product_price: number | null
          product_quantity: number | null
          source: Database["public"]["Enums"]["order_source"]
          transaction_id: string | null
          transaction_id_norm: string | null
          update_time: string | null
          user_cashback_vnd: number
          user_id: string | null
          user_share_bps: number | null
          utm_content: string | null
          value_vnd: number
          vip_bonus_bps: number | null
          withdrawable_at: string | null
        }
        Insert: {
          at_status?: number | null
          category_key?: string | null
          click_id?: number | null
          click_time?: string | null
          commission_vnd?: number
          confirmed_time?: string | null
          conversion_id?: number | null
          created_at?: string
          credit_state?: Database["public"]["Enums"]["credit_state"]
          id?: string
          is_confirmed?: number
          matched_by?: string | null
          merchant_id: string
          order_time?: string | null
          product_id?: string | null
          product_name?: string | null
          product_price?: number | null
          product_quantity?: number | null
          source?: Database["public"]["Enums"]["order_source"]
          transaction_id?: string | null
          transaction_id_norm?: string | null
          update_time?: string | null
          user_cashback_vnd?: number
          user_id?: string | null
          user_share_bps?: number | null
          utm_content?: string | null
          value_vnd?: number
          vip_bonus_bps?: number | null
          withdrawable_at?: string | null
        }
        Update: {
          at_status?: number | null
          category_key?: string | null
          click_id?: number | null
          click_time?: string | null
          commission_vnd?: number
          confirmed_time?: string | null
          conversion_id?: number | null
          created_at?: string
          credit_state?: Database["public"]["Enums"]["credit_state"]
          id?: string
          is_confirmed?: number
          matched_by?: string | null
          merchant_id?: string
          order_time?: string | null
          product_id?: string | null
          product_name?: string | null
          product_price?: number | null
          product_quantity?: number | null
          source?: Database["public"]["Enums"]["order_source"]
          transaction_id?: string | null
          transaction_id_norm?: string | null
          update_time?: string | null
          user_cashback_vnd?: number
          user_id?: string | null
          user_share_bps?: number | null
          utm_content?: string | null
          value_vnd?: number
          vip_bonus_bps?: number | null
          withdrawable_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "orders_click_id_fkey"
            columns: ["click_id"]
            isOneToOne: false
            referencedRelation: "clicks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      price_snapshots: {
        Row: {
          day: string
          offer_id: number
          price: number
        }
        Insert: {
          day: string
          offer_id: number
          price: number
        }
        Update: {
          day?: string
          offer_id?: number
          price?: number
        }
        Relationships: [
          {
            foreignKeyName: "price_snapshots_offer_id_fkey"
            columns: ["offer_id"]
            isOneToOne: false
            referencedRelation: "offers"
            referencedColumns: ["id"]
          },
        ]
      }
      product_groups: {
        Row: {
          created_at: string
          group_key: string
          id: number
        }
        Insert: {
          created_at?: string
          group_key: string
          id?: never
        }
        Update: {
          created_at?: string
          group_key?: string
          id?: never
        }
        Relationships: []
      }
      product_key_rules: {
        Row: {
          brand: string
          id: number
          pattern: string
          priority: number
        }
        Insert: {
          brand: string
          id?: never
          pattern: string
          priority?: number
        }
        Update: {
          brand?: string
          id?: never
          pattern?: string
          priority?: number
        }
        Relationships: []
      }
      profiles: {
        Row: {
          coin_balance: number
          created_at: string
          display_name: string | null
          email: string | null
          has_pin: boolean
          id: string
          locked_at: string | null
          notification_prefs: Json
          onboarded_at: string | null
          referral_code: string
          referred_by: string | null
          short_id: number
          vip_tier_code: string | null
          withdrawal_hold_until: string | null
        }
        Insert: {
          coin_balance?: number
          created_at?: string
          display_name?: string | null
          email?: string | null
          has_pin?: boolean
          id: string
          locked_at?: string | null
          notification_prefs?: Json
          onboarded_at?: string | null
          referral_code?: string
          referred_by?: string | null
          short_id?: never
          vip_tier_code?: string | null
          withdrawal_hold_until?: string | null
        }
        Update: {
          coin_balance?: number
          created_at?: string
          display_name?: string | null
          email?: string | null
          has_pin?: boolean
          id?: string
          locked_at?: string | null
          notification_prefs?: Json
          onboarded_at?: string | null
          referral_code?: string
          referred_by?: string | null
          short_id?: never
          vip_tier_code?: string | null
          withdrawal_hold_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_referred_by_fkey"
            columns: ["referred_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "profiles_vip_tier_code_fkey"
            columns: ["vip_tier_code"]
            isOneToOne: false
            referencedRelation: "vip_tiers"
            referencedColumns: ["code"]
          },
        ]
      }
      push_tokens: {
        Row: {
          created_at: string
          platform: string
          token: string
          user_id: string
        }
        Insert: {
          created_at?: string
          platform: string
          token: string
          user_id: string
        }
        Update: {
          created_at?: string
          platform?: string
          token?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      referrals: {
        Row: {
          bonus_vnd: number
          created_at: string
          id: number
          qualified_order_id: string | null
          referee_id: string
          referrer_id: string
          status: Database["public"]["Enums"]["referral_status"]
        }
        Insert: {
          bonus_vnd?: number
          created_at?: string
          id?: never
          qualified_order_id?: string | null
          referee_id: string
          referrer_id: string
          status?: Database["public"]["Enums"]["referral_status"]
        }
        Update: {
          bonus_vnd?: number
          created_at?: string
          id?: never
          qualified_order_id?: string | null
          referee_id?: string
          referrer_id?: string
          status?: Database["public"]["Enums"]["referral_status"]
        }
        Relationships: [
          {
            foreignKeyName: "referrals_qualified_order_id_fkey"
            columns: ["qualified_order_id"]
            isOneToOne: false
            referencedRelation: "admin_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_qualified_order_id_fkey"
            columns: ["qualified_order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_referee_id_fkey"
            columns: ["referee_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "referrals_referrer_id_fkey"
            columns: ["referrer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_vouchers: {
        Row: {
          created_at: string
          user_id: string
          voucher_id: number
        }
        Insert: {
          created_at?: string
          user_id: string
          voucher_id: number
        }
        Update: {
          created_at?: string
          user_id?: string
          voucher_id?: number
        }
        Relationships: [
          {
            foreignKeyName: "saved_vouchers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "saved_vouchers_voucher_id_fkey"
            columns: ["voucher_id"]
            isOneToOne: false
            referencedRelation: "vouchers"
            referencedColumns: ["id"]
          },
        ]
      }
      sync_errors: {
        Row: {
          conversion_id: number | null
          created_at: string
          error: string | null
          id: number
          job: string
          raw: Json | null
        }
        Insert: {
          conversion_id?: number | null
          created_at?: string
          error?: string | null
          id?: never
          job: string
          raw?: Json | null
        }
        Update: {
          conversion_id?: number | null
          created_at?: string
          error?: string | null
          id?: never
          job?: string
          raw?: Json | null
        }
        Relationships: []
      }
      sync_state: {
        Row: {
          cursor: Json | null
          job: string
          last_error: string | null
          last_success_at: string | null
          locked_until: string | null
        }
        Insert: {
          cursor?: Json | null
          job: string
          last_error?: string | null
          last_success_at?: string | null
          locked_until?: string | null
        }
        Update: {
          cursor?: Json | null
          job?: string
          last_error?: string | null
          last_success_at?: string | null
          locked_until?: string | null
        }
        Relationships: []
      }
      user_activity_days: {
        Row: {
          day: string
          user_id: string
        }
        Insert: {
          day: string
          user_id: string
        }
        Update: {
          day?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_activity_days_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_devices: {
        Row: {
          device_hash: string
          id: number
          last_seen_at: string
          model: string | null
          platform: string
          user_id: string
        }
        Insert: {
          device_hash: string
          id?: never
          last_seen_at?: string
          model?: string | null
          platform: string
          user_id: string
        }
        Update: {
          device_hash?: string
          id?: never
          last_seen_at?: string
          model?: string | null
          platform?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_devices_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_risk: {
        Row: {
          level: string
          lock_reason: string | null
          risk_score: number
          updated_at: string
          user_id: string
        }
        Insert: {
          level?: string
          lock_reason?: string | null
          risk_score?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          level?: string
          lock_reason?: string | null
          risk_score?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_risk_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      vip_tiers: {
        Row: {
          bonus_bps: number
          code: string
          min_gmv_12m_vnd: number
          name: string | null
        }
        Insert: {
          bonus_bps?: number
          code: string
          min_gmv_12m_vnd?: number
          name?: string | null
        }
        Update: {
          bonus_bps?: number
          code?: string
          min_gmv_12m_vnd?: number
          name?: string | null
        }
        Relationships: []
      }
      vouchers: {
        Row: {
          code: string | null
          description: string | null
          discount_text: string | null
          ends_at: string | null
          external_id: string
          id: number
          merchant_id: string
          starts_at: string | null
          title: string | null
          updated_at: string
          url: string | null
        }
        Insert: {
          code?: string | null
          description?: string | null
          discount_text?: string | null
          ends_at?: string | null
          external_id: string
          id?: never
          merchant_id: string
          starts_at?: string | null
          title?: string | null
          updated_at?: string
          url?: string | null
        }
        Update: {
          code?: string | null
          description?: string | null
          discount_text?: string | null
          ends_at?: string | null
          external_id?: string
          id?: never
          merchant_id?: string
          starts_at?: string | null
          title?: string | null
          updated_at?: string
          url?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "vouchers_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
        ]
      }
      wallet_ledger: {
        Row: {
          amount_vnd: number
          available_at: string | null
          created_at: string
          created_by: string | null
          entry_type: Database["public"]["Enums"]["ledger_entry_type"]
          held_remaining: number
          id: number
          idempotency_key: string
          note: string | null
          order_id: string | null
          promoted_at: string | null
          referral_id: number | null
          user_id: string
          withdrawal_id: string | null
        }
        Insert: {
          amount_vnd: number
          available_at?: string | null
          created_at?: string
          created_by?: string | null
          entry_type: Database["public"]["Enums"]["ledger_entry_type"]
          held_remaining?: number
          id?: never
          idempotency_key: string
          note?: string | null
          order_id?: string | null
          promoted_at?: string | null
          referral_id?: number | null
          user_id: string
          withdrawal_id?: string | null
        }
        Update: {
          amount_vnd?: number
          available_at?: string | null
          created_at?: string
          created_by?: string | null
          entry_type?: Database["public"]["Enums"]["ledger_entry_type"]
          held_remaining?: number
          id?: never
          idempotency_key?: string
          note?: string | null
          order_id?: string | null
          promoted_at?: string | null
          referral_id?: number | null
          user_id?: string
          withdrawal_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "wallet_ledger_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "admin_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_ledger_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_ledger_referral_id_fkey"
            columns: ["referral_id"]
            isOneToOne: false
            referencedRelation: "referrals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_ledger_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_ledger_withdrawal_id_fkey"
            columns: ["withdrawal_id"]
            isOneToOne: false
            referencedRelation: "admin_withdrawals"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wallet_ledger_withdrawal_id_fkey"
            columns: ["withdrawal_id"]
            isOneToOne: false
            referencedRelation: "withdrawals"
            referencedColumns: ["id"]
          },
        ]
      }
      wallets: {
        Row: {
          available_vnd: number
          held_vnd: number
          pending_vnd: number
          total_earned_vnd: number
          updated_at: string
          user_id: string
        }
        Insert: {
          available_vnd?: number
          held_vnd?: number
          pending_vnd?: number
          total_earned_vnd?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          available_vnd?: number
          held_vnd?: number
          pending_vnd?: number
          total_earned_vnd?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wallets_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      watchlist_items: {
        Row: {
          created_at: string
          id: number
          last_notified_at: string | null
          product_group_id: number
          target_price_vnd: number
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: never
          last_notified_at?: string | null
          product_group_id: number
          target_price_vnd: number
          user_id: string
        }
        Update: {
          created_at?: string
          id?: never
          last_notified_at?: string | null
          product_group_id?: number
          target_price_vnd?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "watchlist_items_product_group_id_fkey"
            columns: ["product_group_id"]
            isOneToOne: false
            referencedRelation: "product_groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "watchlist_items_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      withdrawals: {
        Row: {
          account_name: string
          account_number: string
          amount: number
          bank_account_id: string | null
          bank_bin: string
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          id: string
          paid_at: string | null
          paid_by: string | null
          reject_reason: string | null
          request_key: string
          risk_level: string
          status: Database["public"]["Enums"]["withdrawal_status"]
          transfer_ref: string | null
          user_id: string
        }
        Insert: {
          account_name: string
          account_number: string
          amount: number
          bank_account_id?: string | null
          bank_bin: string
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          id?: string
          paid_at?: string | null
          paid_by?: string | null
          reject_reason?: string | null
          request_key: string
          risk_level?: string
          status?: Database["public"]["Enums"]["withdrawal_status"]
          transfer_ref?: string | null
          user_id: string
        }
        Update: {
          account_name?: string
          account_number?: string
          amount?: number
          bank_account_id?: string | null
          bank_bin?: string
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          id?: string
          paid_at?: string | null
          paid_by?: string | null
          reject_reason?: string | null
          request_key?: string
          risk_level?: string
          status?: Database["public"]["Enums"]["withdrawal_status"]
          transfer_ref?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "withdrawals_bank_account_id_fkey"
            columns: ["bank_account_id"]
            isOneToOne: false
            referencedRelation: "bank_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "withdrawals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      admin_orders: {
        Row: {
          at_status: number | null
          category_key: string | null
          click_id: number | null
          click_time: string | null
          commission_vnd: number | null
          confirmed_time: string | null
          conversion_id: number | null
          created_at: string | null
          credit_state: Database["public"]["Enums"]["credit_state"] | null
          id: string | null
          is_confirmed: number | null
          matched_by: string | null
          merchant_id: string | null
          order_time: string | null
          product_id: string | null
          product_name: string | null
          product_price: number | null
          product_quantity: number | null
          source: Database["public"]["Enums"]["order_source"] | null
          transaction_id: string | null
          transaction_id_norm: string | null
          update_time: string | null
          user_cashback_vnd: number | null
          user_id: string | null
          user_share_bps: number | null
          utm_content: string | null
          value_vnd: number | null
          vip_bonus_bps: number | null
          withdrawable_at: string | null
        }
        Insert: {
          at_status?: number | null
          category_key?: string | null
          click_id?: number | null
          click_time?: string | null
          commission_vnd?: number | null
          confirmed_time?: string | null
          conversion_id?: number | null
          created_at?: string | null
          credit_state?: Database["public"]["Enums"]["credit_state"] | null
          id?: string | null
          is_confirmed?: number | null
          matched_by?: string | null
          merchant_id?: string | null
          order_time?: string | null
          product_id?: string | null
          product_name?: string | null
          product_price?: number | null
          product_quantity?: number | null
          source?: Database["public"]["Enums"]["order_source"] | null
          transaction_id?: string | null
          transaction_id_norm?: string | null
          update_time?: string | null
          user_cashback_vnd?: number | null
          user_id?: string | null
          user_share_bps?: number | null
          utm_content?: string | null
          value_vnd?: number | null
          vip_bonus_bps?: number | null
          withdrawable_at?: string | null
        }
        Update: {
          at_status?: number | null
          category_key?: string | null
          click_id?: number | null
          click_time?: string | null
          commission_vnd?: number | null
          confirmed_time?: string | null
          conversion_id?: number | null
          created_at?: string | null
          credit_state?: Database["public"]["Enums"]["credit_state"] | null
          id?: string | null
          is_confirmed?: number | null
          matched_by?: string | null
          merchant_id?: string | null
          order_time?: string | null
          product_id?: string | null
          product_name?: string | null
          product_price?: number | null
          product_quantity?: number | null
          source?: Database["public"]["Enums"]["order_source"] | null
          transaction_id?: string | null
          transaction_id_norm?: string | null
          update_time?: string | null
          user_cashback_vnd?: number | null
          user_id?: string | null
          user_share_bps?: number | null
          utm_content?: string | null
          value_vnd?: number | null
          vip_bonus_bps?: number | null
          withdrawable_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "orders_click_id_fkey"
            columns: ["click_id"]
            isOneToOne: false
            referencedRelation: "clicks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_merchant_id_fkey"
            columns: ["merchant_id"]
            isOneToOne: false
            referencedRelation: "merchants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "orders_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_withdrawals: {
        Row: {
          account_name: string | null
          account_number: string | null
          amount: number | null
          bank_account_id: string | null
          bank_bin: string | null
          claimed_at: string | null
          claimed_by: string | null
          created_at: string | null
          id: string | null
          paid_at: string | null
          paid_by: string | null
          reject_reason: string | null
          request_key: string | null
          risk_level: string | null
          status: Database["public"]["Enums"]["withdrawal_status"] | null
          transfer_ref: string | null
          user_id: string | null
        }
        Insert: {
          account_name?: string | null
          account_number?: string | null
          amount?: number | null
          bank_account_id?: string | null
          bank_bin?: string | null
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string | null
          id?: string | null
          paid_at?: string | null
          paid_by?: string | null
          reject_reason?: string | null
          request_key?: string | null
          risk_level?: string | null
          status?: Database["public"]["Enums"]["withdrawal_status"] | null
          transfer_ref?: string | null
          user_id?: string | null
        }
        Update: {
          account_name?: string | null
          account_number?: string | null
          amount?: number | null
          bank_account_id?: string | null
          bank_bin?: string | null
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string | null
          id?: string | null
          paid_at?: string | null
          paid_by?: string | null
          reject_reason?: string | null
          request_key?: string | null
          risk_level?: string | null
          status?: Database["public"]["Enums"]["withdrawal_status"] | null
          transfer_ref?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "withdrawals_bank_account_id_fkey"
            columns: ["bank_account_id"]
            isOneToOne: false
            referencedRelation: "bank_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "withdrawals_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      add_bank_account: {
        Args: {
          p_account_name: string
          p_account_number: string
          p_bank_bin: string
        }
        Returns: string
      }
      admin_adjust_wallet: {
        Args: {
          p_amount: number
          p_order_id?: string
          p_reason: string
          p_user_id: string
        }
        Returns: number
      }
      admin_assign_order: {
        Args: { p_order_id: string; p_user_id: string }
        Returns: undefined
      }
      admin_claim_withdrawal: {
        Args: { p_id: string }
        Returns: {
          claimed_at: string
          claimed_by: string
          id: string
          status: Database["public"]["Enums"]["withdrawal_status"]
        }[]
      }
      admin_mark_paid: {
        Args: { p_ids: string[]; p_transfer_ref: string }
        Returns: {
          error: string
          id: string
          ok: boolean
        }[]
      }
      admin_merchant_mix: {
        Args: { p_from: string; p_to: string }
        Returns: {
          commission_vnd: number
          merchant_id: string
          share: number
        }[]
      }
      admin_monthly_series: {
        Args: { p_months?: number }
        Returns: {
          commission_vnd: number
          month: string
          net_vnd: number
          paid_vnd: number
        }[]
      }
      admin_overview: {
        Args: { p_from: string; p_to: string }
        Returns: {
          commission_vnd: number
          gmv_vnd: number
          net_vnd: number
          paid_to_users_vnd: number
          pending_commission_vnd: number
          sync_errors_24h: number
          unmatched_count: number
          unmatched_ratio: number
        }[]
      }
      admin_reject_withdrawals: {
        Args: { p_ids: string[]; p_reason: string }
        Returns: {
          error: string
          id: string
          ok: boolean
        }[]
      }
      admin_resolve_complaint: {
        Args: {
          p_amount: number
          p_decision: string
          p_id: number
          p_note: string
        }
        Returns: string
      }
      admin_review_kyc: {
        Args: { p_decision: string; p_reason: string; p_user_id: string }
        Returns: undefined
      }
      admin_set_setting: {
        Args: { p_key: string; p_value: Json }
        Returns: undefined
      }
      admin_set_user_lock: {
        Args: { p_locked: boolean; p_reason: string; p_user_id: string }
        Returns: undefined
      }
      admin_top_users: {
        Args: { p_limit?: number }
        Returns: {
          cashback_vnd: number
          email: string
          gmv_vnd: number
          orders: number
          user_id: string
        }[]
      }
      admin_update_flag: {
        Args: {
          p_flag_id: number
          p_status: Database["public"]["Enums"]["flag_status"]
        }
        Returns: undefined
      }
      admin_update_vip_tier: {
        Args: { p_bonus_bps: number; p_code: string; p_min_gmv: number }
        Returns: undefined
      }
      admin_upsert_cashback_rule: {
        Args: {
          p_category_key: string
          p_enabled: boolean
          p_merchant_id: string
          p_note: string
          p_user_share_bps: number
        }
        Returns: number
      }
      admin_user_stats: { Args: { p_days?: number }; Returns: Json }
      admin_verify_bank_account: { Args: { p_id: string }; Returns: undefined }
      approve_extension_login: { Args: { p_code: string }; Returns: undefined }
      assign_product_groups: { Args: never; Returns: number }
      at_rate_limit_take: {
        Args: { p_bucket?: string; p_cost: number }
        Returns: boolean
      }
      bind_referral: { Args: { p_code: string }; Returns: undefined }
      check_wallet_drift: {
        Args: never
        Returns: {
          field: string
          ledger_vnd: number
          user_id: string
          wallet_vnd: number
        }[]
      }
      claim_mission: { Args: { p_code: string }; Returns: number }
      claim_push_batch: {
        Args: { p_limit: number }
        Returns: {
          body: string
          data: Json
          id: number
          title: string
          tokens: string[]
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }[]
      }
      complete_onboarding: { Args: never; Returns: undefined }
      consume_extension_login: {
        Args: { p_code: string; p_secret: string }
        Returns: string
      }
      create_click: {
        Args: {
          p_device_hash: string
          p_merchant_id: string
          p_offer_id: number
          p_origin_url: string
          p_resolved_url: string
          p_source: Database["public"]["Enums"]["click_source"]
          p_user_id: string
        }
        Returns: {
          aff_link: string
          click_id: number
          short_link: string
          utm_content: string
        }[]
      }
      daily_checkin: {
        Args: never
        Returns: {
          coins: number
          streak: number
        }[]
      }
      estimate_cashback: {
        Args: {
          p_category_key: string
          p_merchant_id: string
          p_order_value: number
          p_tier_code?: string
        }
        Returns: {
          app_keeps_vnd: number
          base_cashback_vnd: number
          base_rate_bps: number
          commission_vnd: number
          user_cashback_vnd: number
          vip_bonus_vnd: number
          vip_rate_bps: number
        }[]
      }
      evaluate_price_alerts: { Args: never; Returns: number }
      get_compare: {
        Args: { p_group_id: number }
        Returns: {
          cashback_eligible: boolean
          effective_price_vnd: number
          est_cashback_vnd: number
          image_url: string
          is_mall: boolean
          list_price_vnd: number
          merchant_id: string
          name: string
          offer_id: number
          price_vnd: number
          shop_name: string
          url: string
        }[]
      }
      get_extension_login_request: {
        Args: { p_code: string }
        Returns: {
          expires_at: string
          ip_masked: string
          user_agent: string
        }[]
      }
      get_merchant_rates: {
        Args: never
        Returns: {
          activation_hours: number
          badge_letter: string
          datafeed_enabled: boolean
          domains: string[]
          extension_enabled: boolean
          hold_days: number
          link_api: string
          max_user_rate_bps: number
          merchant_id: string
          name: string
        }[]
      }
      get_mission_progress: {
        Args: never
        Returns: {
          claimed: boolean
          code: string
          progress: number
          reward_amount: number
          reward_kind: string
          target: number
          title: string
        }[]
      }
      get_price_history: {
        Args: { p_days: number; p_group_id: number }
        Returns: {
          day: string
          min_price_vnd: number
        }[]
      }
      get_public_settings: { Args: never; Returns: Json }
      ingest_at_transactions: {
        Args: { p_job: string; p_rows: Json }
        Returns: {
          conversion_id: number
          status: string
        }[]
      }
      is_admin: { Args: never; Returns: boolean }
      mark_notifications_read: { Args: { p_ids?: number[] }; Returns: number }
      mark_push_sent: { Args: { p_ids: number[] }; Returns: undefined }
      promote_withdrawable: { Args: never; Returns: number }
      record_link_share: { Args: { p_click_id: number }; Returns: undefined }
      refresh_risk_scores: { Args: never; Returns: number }
      refresh_vip_tiers: { Args: never; Returns: number }
      register_device: {
        Args: { p_device_id: string; p_model: string; p_platform: string }
        Returns: undefined
      }
      request_withdrawal: {
        Args: {
          p_amount: number
          p_bank_account_id: string
          p_pin_token: string
          p_request_key: string
        }
        Returns: {
          status: Database["public"]["Enums"]["withdrawal_status"]
          withdrawal_id: string
        }[]
      }
      search_offers: {
        Args: {
          p_limit?: number
          p_merchants?: string[]
          p_offset?: number
          p_q: string
          p_sort?: string
        }
        Returns: {
          est_cashback_vnd: number
          image_url: string
          merchant_id: string
          name: string
          offer_id: number
          offers_in_group: number
          price_vnd: number
          product_group_id: number
          rate_bps: number
        }[]
      }
      set_click_link: {
        Args: { p_aff_link: string; p_click_id: number; p_short_link: string }
        Returns: undefined
      }
      set_withdraw_pin: {
        Args: { p_new: string; p_pin_token?: string }
        Returns: undefined
      }
      start_extension_login: {
        Args: { p_ip: unknown; p_secret_hash: string; p_user_agent: string }
        Returns: {
          code: string
          expires_at: string
        }[]
      }
      submit_kyc: {
        Args: {
          p_back_path: string
          p_front_path: string
          p_full_name: string
          p_id_number: string
        }
        Returns: Database["public"]["Enums"]["kyc_status"]
      }
      submit_missing_order: {
        Args: {
          p_image_paths: string[]
          p_merchant_id: string
          p_order_code: string
          p_purchased_on: string
          p_value: number
        }
        Returns: string
      }
      sync_finish: {
        Args: {
          p_error: string
          p_job: string
          p_success: boolean
          p_window_until: string
        }
        Returns: undefined
      }
      sync_lock: { Args: { p_job: string; p_ttl_s: number }; Returns: boolean }
      sync_save: { Args: { p_cursor: Json; p_job: string }; Returns: undefined }
      touch_activity: { Args: never; Returns: undefined }
      update_profile: {
        Args: { p_display_name: string; p_notification_prefs: Json }
        Returns: undefined
      }
      upsert_campaign_commissions: { Args: { p_rows: Json }; Returns: number }
      upsert_offers: {
        Args: { p_merchant_id: string; p_rows: Json }
        Returns: {
          snapshots: number
          upserted: number
        }[]
      }
      upsert_vouchers: { Args: { p_rows: Json }; Returns: number }
      verify_pin: {
        Args: { p_pin: string }
        Returns: {
          attempts_left: number
          locked_until: string
          ok: boolean
          pin_token: string
        }[]
      }
    }
    Enums: {
      click_source: "app" | "extension"
      click_status: "pending" | "ok" | "failed"
      credit_state: "none" | "pending" | "credited" | "cancelled" | "reversed"
      flag_status: "open" | "dismissed" | "actioned"
      fraud_type:
        | "multi_account_device"
        | "shared_identity"
        | "shared_bank_account"
        | "abnormal_clicks"
        | "self_referral"
        | "order_claim_conflict"
        | "negative_balance_risk"
      kyc_status: "pending" | "verified" | "rejected"
      ledger_entry_type:
        | "cashback_credit"
        | "cashback_reversal"
        | "withdrawal_debit"
        | "withdrawal_refund"
        | "referral_bonus"
        | "referral_reversal"
        | "mission_bonus"
        | "manual_credit"
        | "manual_reversal"
        | "admin_adjustment"
      notification_type: "order" | "wallet" | "promo" | "referral" | "system"
      order_source: "accesstrade" | "manual"
      referral_status: "pending" | "qualified" | "rewarded" | "held" | "void"
      withdrawal_status: "pending" | "processing" | "paid" | "rejected"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      click_source: ["app", "extension"],
      click_status: ["pending", "ok", "failed"],
      credit_state: ["none", "pending", "credited", "cancelled", "reversed"],
      flag_status: ["open", "dismissed", "actioned"],
      fraud_type: [
        "multi_account_device",
        "shared_identity",
        "shared_bank_account",
        "abnormal_clicks",
        "self_referral",
        "order_claim_conflict",
        "negative_balance_risk",
      ],
      kyc_status: ["pending", "verified", "rejected"],
      ledger_entry_type: [
        "cashback_credit",
        "cashback_reversal",
        "withdrawal_debit",
        "withdrawal_refund",
        "referral_bonus",
        "referral_reversal",
        "mission_bonus",
        "manual_credit",
        "manual_reversal",
        "admin_adjustment",
      ],
      notification_type: ["order", "wallet", "promo", "referral", "system"],
      order_source: ["accesstrade", "manual"],
      referral_status: ["pending", "qualified", "rewarded", "held", "void"],
      withdrawal_status: ["pending", "processing", "paid", "rejected"],
    },
  },
} as const

