package com.example.flutter_braintree;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;

import com.braintreepayments.api.DropInClient;
import com.braintreepayments.api.DropInListener;
import com.braintreepayments.api.DropInRequest;
import com.braintreepayments.api.DropInResult;
import com.braintreepayments.api.GooglePayRequest;
import com.braintreepayments.api.UserCanceledException;
import com.google.android.gms.wallet.TransactionInfo;
import com.google.android.gms.wallet.WalletConstants;

public class DropInActivity extends AppCompatActivity implements DropInListener {
    private static final String TAG = "DropInActivity";
    private DropInClient dropInClient;
    private DropInRequest dropInRequest;
    private boolean isDropInStarted = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_flutter_braintree_drop_in);

        Log.d(TAG, "onCreate called");
        // Retrieve the token and DropInRequest from the intent
        Intent intent = getIntent();
        String token = intent.getStringExtra("token");
        Log.d(TAG, "Received token: " + token);
        if (token == null) {
            Log.e(TAG, "Authorization token is required but was null");
            handleError(new IllegalArgumentException("Authorization token is required."));
            return;
        }

        dropInRequest = intent.getParcelableExtra("dropInRequest");
        Log.d(TAG, "Received dropInRequest: " + (dropInRequest != null ? dropInRequest.toString() : "null"));
        if (dropInRequest == null) {
            Log.e(TAG, "DropInRequest is required but was null");
            handleError(new IllegalArgumentException("DropInRequest is required."));
            return;
        }

        // Initialize DropInClient and set the listener
        dropInClient = new DropInClient(this, token);
        dropInClient.setListener(this);
        Log.d(TAG, "DropInClient initialized and listener set");
    }

    @Override
    protected void onStart() {
        super.onStart();
        Log.d(TAG, "onStart called, isDropInStarted=" + isDropInStarted);
        if (!isDropInStarted) {
            isDropInStarted = true;
            Log.d(TAG, "Launching DropIn with dropInRequest: " + dropInRequest);
            dropInClient.launchDropIn(dropInRequest);
        }
    }

    @Override
    public void onDropInSuccess(@NonNull DropInResult dropInResult) {
        Log.d(TAG, "onDropInSuccess: " + dropInResult);
        // Handle successful Drop-in result
        isDropInStarted = false;
        Intent result = new Intent();
        result.putExtra("dropInResult", dropInResult);
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onDropInFailure(@NonNull Exception error) {
        Log.e(TAG, "onDropInFailure: " + error.getMessage(), error);
        // Handle Drop-in failure
        isDropInStarted = false;
        if (error instanceof UserCanceledException) {
            // User explicitly canceled the Drop-in flow
            setResult(RESULT_CANCELED);
        } else {
            // Other errors
            Intent result = new Intent();
            result.putExtra("error", error.getMessage());
            setResult(RESULT_CANCELED, result);
        }
        finish();
    }

    private void handleError(Exception error) {
        Log.e(TAG, "handleError: " + error.getMessage(), error);
        // Handle initialization errors
        Intent result = new Intent();
        result.putExtra("error", error.getMessage());
        setResult(RESULT_CANCELED, result);
        finish();
    }
}