package com.ufine.foresee

import android.animation.Animator
import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.graphics.Rect
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.view.ViewTreeObserver
import android.view.animation.DecelerateInterpolator
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class OverlayService : Service() {
    private var windowManager: WindowManager? = null
    private var overlayView: android.view.View? = null
    private var messagesContainer: LinearLayout? = null
    private var barContainer: View? = null

    private data class OverlayMessage(val text: String, val isUser: Boolean)
    private val messages = mutableListOf<OverlayMessage>()

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        addOverlay()
    }

    private fun addOverlay() {
        if (windowManager == null || overlayView != null) return

        // Güvenlik için overlay izni tekrar kontrol et
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) {
            stopSelf()
            return
        }

        val inflater = LayoutInflater.from(this)
        val view = inflater.inflate(R.layout.overlay_input, null)
        overlayView = view

        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL

        windowManager?.addView(view, params)

        val dimView = view.findViewById<View>(R.id.overlay_dim)
        val line1 = view.findViewById<View>(R.id.overlay_line1)
        val line2 = view.findViewById<View>(R.id.overlay_line2)
        barContainer = view.findViewById(R.id.overlay_bar_container)
        messagesContainer = view.findViewById(R.id.overlay_messages_container)

        // Gri alanı ekranın yaklaşık yarısı yap
        dimView?.let { dv ->
            val dm = resources.displayMetrics
            val halfHeight = (dm.heightPixels * 0.5f).toInt()
            val lp = dv.layoutParams
            lp.height = halfHeight
            dv.layoutParams = lp
            dv.alpha = 0f
        }
        line1?.alpha = 0f
        line2?.alpha = 0f
        barContainer?.alpha = 0f
        barContainer?.translationY = 80f

        // Klavye açıldığında input bar'ı yukarı taşımak için global layout dinleyicisi ekle
        view.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            private var lastKeyboardVisible = false

            override fun onGlobalLayout() {
                val root = overlayView ?: return
                val r = Rect()
                root.getWindowVisibleDisplayFrame(r)
                val screenHeight = resources.displayMetrics.heightPixels
                val keyboardHeight = screenHeight - r.bottom
                val keyboardVisible = keyboardHeight > screenHeight * 0.15f

                if (keyboardVisible != lastKeyboardVisible) {
                    lastKeyboardVisible = keyboardVisible
                    barContainer?.let { bar ->
                        bar.translationY = if (keyboardVisible) {
                            -keyboardHeight.toFloat()
                        } else {
                            0f
                        }
                    }
                }
            }
        })

        view.post {
            val anims = mutableListOf<Animator>()

            dimView?.let {
                anims += ObjectAnimator.ofFloat(it, View.ALPHA, 0f, 1f).apply {
                    duration = 200
                }
            }

            line1?.let {
                it.scaleX = 0f
                anims += ObjectAnimator.ofFloat(it, View.ALPHA, 0f, 1f).apply {
                    duration = 260
                }
                anims += ObjectAnimator.ofFloat(it, View.SCALE_X, 0f, 1f).apply {
                    duration = 260
                }
            }

            line2?.let {
                it.scaleX = 0f
                anims += ObjectAnimator.ofFloat(it, View.ALPHA, 0f, 1f).apply {
                    duration = 260
                    startDelay = 80
                }
                anims += ObjectAnimator.ofFloat(it, View.SCALE_X, 0f, 1f).apply {
                    duration = 260
                    startDelay = 80
                }
            }

            barContainer?.let {
                anims += ObjectAnimator.ofFloat(it, View.TRANSLATION_Y, 80f, 0f).apply {
                    duration = 320
                    startDelay = 120
                }
                anims += ObjectAnimator.ofFloat(it, View.ALPHA, 0f, 1f).apply {
                    duration = 320
                    startDelay = 120
                }
            }

            if (anims.isNotEmpty()) {
                val set = AnimatorSet()
                set.playTogether(anims)
                set.interpolator = DecelerateInterpolator()
                set.start()
            }
        }

        val input = view.findViewById<EditText>(R.id.et_overlay_input)
        val sendButton = view.findViewById<ImageButton>(R.id.btn_overlay_send)
        val cameraButton = view.findViewById<ImageButton>(R.id.btn_overlay_camera)
        val closeButton = view.findViewById<ImageButton>(R.id.btn_overlay_close)

        sendButton.setOnClickListener {
            val text = input.text.toString().trim()
            if (text.isEmpty()) {
                Toast.makeText(this, "Boş mesaj gönderilemez", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            input.setText("")
            addMessage(OverlayMessage(text, true))
            callOpenRouter(text)
        }

        cameraButton.setOnClickListener {
            Toast.makeText(this, "Ekran görüntüsü entegrasyonu daha sonra eklenecek", Toast.LENGTH_SHORT).show()
        }

        closeButton?.setOnClickListener {
            // X'e basınca asistan overlay'ini kapat
            stopSelf()
        }
    }

    private fun addMessage(message: OverlayMessage) {
        messages.add(message)
        // Son 4 mesajı gösterelim
        val lastMessages = messages.takeLast(4)
        val container = messagesContainer ?: return

        mainHandler.post {
            container.removeAllViews()
            // Balon genişliği ekranın yaklaşık %94'ü kadar olsun (uygulamadaki gibi daha geniş)
            val maxBubbleWidth = (resources.displayMetrics.widthPixels * 0.94f).toInt()

            lastMessages.forEach { msg ->
                val row = LinearLayout(this).apply {
                    orientation = LinearLayout.HORIZONTAL
                    layoutParams = LinearLayout.LayoutParams(
                        LinearLayout.LayoutParams.MATCH_PARENT,
                        LinearLayout.LayoutParams.WRAP_CONTENT
                    ).apply {
                        topMargin = 10
                    }
                    gravity = if (msg.isUser) Gravity.END else Gravity.START
                }

                val tv = TextView(this).apply {
                    text = msg.text
                    setTextColor(0xFFFFFFFF.toInt())
                    // Uygulamadaki mesaja daha yakın boyut
                    textSize = 15.5f
                    setPadding(22, 14, 22, 14)
                    maxLines = 8
                    maxWidth = maxBubbleWidth
                    background = resources.getDrawable(R.drawable.overlay_bubble_bg, null)
                }

                row.addView(tv)
                container.addView(row)
            }
        }
    }

    private fun callOpenRouter(userMessage: String) {
        Thread {
            try {
                // Dart tarafındaki OpenRouterService ile aynı değerler
                val apiKey = ""
                val apiUrl = "https://openrouter.ai/api/v1/chat/completions"
                val model = "qwen/qwen2.5-vl-32b-instruct:free"

                val systemContent = "ForeSee asistanısın. Kısa ve öz, Türkçe cevap ver."

                val messagesArray = JSONArray().apply {
                    put(JSONObject().apply {
                        put("role", "system")
                        put("content", systemContent)
                    })
                    put(JSONObject().apply {
                        put("role", "user")
                        put("content", userMessage)
                    })
                }

                val payload = JSONObject().apply {
                    put("model", model)
                    put("messages", messagesArray)
                    put("max_tokens", 512)
                    put("temperature", 0.7)
                }

                val url = URL(apiUrl)
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 30000
                    readTimeout = 30000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Authorization", "Bearer $apiKey")
                    setRequestProperty("HTTP-Referer", "https://foresee.app")
                    setRequestProperty("X-Title", "ForeSee AI")
                }

                conn.outputStream.use { os ->
                    os.write(payload.toString().toByteArray(Charsets.UTF_8))
                }

                val responseCode = conn.responseCode
                val responseBuilder = StringBuilder()
                val reader = if (responseCode in 200..299) {
                    BufferedReader(InputStreamReader(conn.inputStream))
                } else {
                    BufferedReader(InputStreamReader(conn.errorStream))
                }

                reader.useLines { lines ->
                    lines.forEach { line ->
                        responseBuilder.append(line)
                    }
                }

                if (responseCode !in 200..299) {
                    throw Exception("API hatası: $responseCode - ${responseBuilder.toString()}")
                }

                val json = JSONObject(responseBuilder.toString())
                val choices = json.getJSONArray("choices")
                if (choices.length() == 0) throw Exception("Boş cevap")
                val first = choices.getJSONObject(0)
                val message = first.getJSONObject("message")
                val content = message.getString("content")

                addMessage(OverlayMessage(content.trim(), false))
            } catch (e: Exception) {
                mainHandler.post {
                    Toast.makeText(this, "Asistan hatası: ${e.message}", Toast.LENGTH_SHORT).show()
                }
            }
        }.start()
    }

    override fun onDestroy() {
        super.onDestroy()
        if (overlayView != null) {
            windowManager?.removeView(overlayView)
            overlayView = null
        }
    }
}
