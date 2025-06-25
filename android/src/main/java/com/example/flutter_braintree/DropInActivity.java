package com.example.flutter_braintree;

import android.content.Intent;
import android.os.Bundle;

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
    private DropInClient dropInClient;
    private DropInRequest dropInRequest;
    private boolean isDropInStarted = false;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_flutter_braintree_drop_in);

        // Retrieve the token and DropInRequest from the intent
        Intent intent = getIntent();
        String token = intent.getStringExtra("token");
        if (token == null) {
            handleError(new IllegalArgumentException("Authorization token is required."));
            return;
        }

        dropInRequest = intent.getParcelableExtra("dropInRequest");
        if (dropInRequest == null) {
            handleError(new IllegalArgumentException("DropInRequest is required."));
            return;
        }

        // Initialize DropInClient and set the listener
        dropInClient = new DropInClient(this, token);
        dropInClient.setListener(this);
    }

    @Override
    protected void onStart() {
        super.onStart();
        if (!isDropInStarted) {
            isDropInStarted = true;
            dropInClient.launchDropIn(dropInRequest);
        }
    }

    @Override
    public void onDropInSuccess(@NonNull DropInResult dropInResult) {
        // Handle successful Drop-in result
        isDropInStarted = false;
        Intent result = new Intent();
        result.putExtra("dropInResult", dropInResult);
        setResult(RESULT_OK, result);
        finish();
    }

    @Override
    public void onDropInFailure(@NonNull Exception error) {
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
        // Handle initialization errors
        Intent result = new Intent();
        result.putExtra("error", error.getMessage());
        setResult(RESULT_CANCELED, result);
        finish();
    }
}