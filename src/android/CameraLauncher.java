package cordova.plugins.CameraModule;

import android.Manifest;
import android.app.Dialog;
import android.app.ProgressDialog;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.hardware.Camera;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Bundle;
import android.os.Environment;
import android.text.TextUtils;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.LOG;
import org.apache.cordova.PermissionHelper;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.net.URI;

import static android.view.View.GONE;

public class CameraLauncher extends CordovaPlugin implements SensorEventListener {

	public static final int PERMISSION_DENIED_ERROR = 20;
	public static final int TAKE_PIC_SEC = 0;
	protected final static String[] permissions = {Manifest.permission.CAMERA, Manifest.permission.READ_EXTERNAL_STORAGE};
	private static final String LOG_TAG = "CameraLauncher";
	public CallbackContext callbackContext;
	ProgressDialog progress;
	Camera.PictureCallback myPictureCallback_JPG = new Camera.PictureCallback() {

		@Override
		public void onPictureTaken(byte[] data, Camera camera) {

			File file = saveImage(data);
			if (file != null) {
				URI uri = file.toURI();
				CameraLauncher.this.callbackContext.success(uri.toString());

				LOG.d(LOG_TAG, uri.toString());
			}

			final String pleaseWait = "Please wait while processing the image";

			cordova.getActivity().runOnUiThread(new Runnable() {
				public void run() {
					progress = ProgressDialog.show(CameraLauncher.this.cordova.getActivity(), "", pleaseWait, true);
				}
			});

		}
	};
	private Preview mPreview;
	private Camera mCamera;
	private SensorManager mSensorManager;
	private android.hardware.Sensor mLight;
	private boolean hasLightSensor = true;
	private String mFlashMode = "";
	private LinearLayout mMessageLayout;
	private TextView mMessageText;
	private FrameLayout backLayout;
	private FrameLayout preview;
	private Dialog cameraScene;
	private Boolean fixedImage = false;
	private Boolean imageActive = true;

	/**
	 * A safe way to get an instance of the Camera object.
	 */
	public static Camera getCameraInstance() {
		Camera camera = null;
		try {
			camera = Camera.open(); // attempt to get a Camera instance
		} catch (Exception e) {
			LOG.d(LOG_TAG, " Camera is not available ");
		}
		return camera;
	}

	@Override
	public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
		this.callbackContext = callbackContext;

		if (action.equals("getPicture")) {
			createView();

			PluginResult r = new PluginResult(PluginResult.Status.NO_RESULT);
			r.setKeepCallback(true);
			callbackContext.sendPluginResult(r);

			return true;
		} else if (action.equals("pictureRecognized")) {
			if (progress != null) {
				cordova.getActivity().runOnUiThread(new Runnable() {
					public void run() {
						progress.dismiss();
					}
				});
			}
			return true;
		}
		return false;
	}

	public void takePermissions() {
		boolean saveAlbumPermission = PermissionHelper.hasPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE);
		boolean takePicturePermission = PermissionHelper.hasPermission(this, Manifest.permission.CAMERA);

		// CB-10120: The CAMERA permission does not need to be requested unless it is declared
		// in AndroidManifest.xml. This plugin does not declare it, but others may and so we must
		// check the package info to determine if the permission is present.

		if (!takePicturePermission) {
			takePicturePermission = true;
			try {
				PackageManager packageManager = this.cordova.getActivity().getPackageManager();
				String[] permissionsInPackage = packageManager.getPackageInfo(this.cordova.getActivity().getPackageName(), PackageManager.GET_PERMISSIONS).requestedPermissions;
				if (permissionsInPackage != null) {
					for (String permission : permissionsInPackage) {
						if (permission.equals(Manifest.permission.CAMERA)) {
							takePicturePermission = false;
							break;
						}
					}
				}
			} catch (PackageManager.NameNotFoundException e) {
				// We are requesting the info for our package, so this should
				// never be caught
			}
		}

		if (takePicturePermission && saveAlbumPermission) {
			addPreview();
		} else if (saveAlbumPermission && !takePicturePermission) {
			PermissionHelper.requestPermission(this, TAKE_PIC_SEC, Manifest.permission.CAMERA);
		} else if (!saveAlbumPermission && takePicturePermission) {
			PermissionHelper.requestPermission(this, TAKE_PIC_SEC, Manifest.permission.READ_EXTERNAL_STORAGE);
		} else {
			PermissionHelper.requestPermissions(this, TAKE_PIC_SEC, permissions);
		}
	}

	public void onRequestPermissionResult(int requestCode, String[] permissions,
	                                      int[] grantResults) throws JSONException {
		for (int r : grantResults) {
			if (r == PackageManager.PERMISSION_DENIED) {
				this.callbackContext.sendPluginResult(new PluginResult(PluginResult.Status.ERROR, PERMISSION_DENIED_ERROR));
				return;
			}
		}
		switch (requestCode) {
			case TAKE_PIC_SEC:
				addPreview();
				break;
		}
	}

	private void takePicture() {
		if (imageActive) {
			mPreview.getCamera().takePicture(null, null, myPictureCallback_JPG);
			imageActive = false;
		} else {
			LOG.d(LOG_TAG, "Start preview");

			mMessageText.setText("");
			mMessageLayout.setVisibility(GONE);

			mCamera.startPreview();
			imageActive = true;
		}
	}

	public void failPicture(String err) {
		this.callbackContext.error(err);
	}

	protected void createView() {

		final FrameLayout baseFrame = new FrameLayout(this.cordova.getActivity().getApplicationContext());
		final FrameLayout.LayoutParams baseFrameLP = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
		baseFrame.setBackgroundColor(Color.parseColor("#FFFFFF"));
		baseFrame.setLayoutParams(baseFrameLP);

		preview = new FrameLayout(this.cordova.getActivity().getApplicationContext());
		FrameLayout.LayoutParams previewLP = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
		preview.setBackgroundColor(Color.parseColor("#000000"));
		preview.setLayoutParams(previewLP);
		baseFrame.addView(preview);

		LinearLayout linearLayout = new LinearLayout(this.cordova.getActivity().getApplicationContext());
		LinearLayout.LayoutParams llLP = new LinearLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
		linearLayout.setOrientation(LinearLayout.VERTICAL);
		linearLayout.setLayoutParams(llLP);

		backLayout = new FrameLayout(this.cordova.getActivity().getApplicationContext());
		FrameLayout.LayoutParams backLayoutLP = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.WRAP_CONTENT);
		backLayout.setBackgroundColor(Color.parseColor("#000000"));
		backLayout.setPadding(5, 5, 5, 5);
		backLayout.setLayoutParams(backLayoutLP);

		ImageView imageView = new ImageView(this.cordova.getActivity().getApplicationContext());
		WindowManager.LayoutParams imageViewLP = new WindowManager.LayoutParams();
		imageViewLP.width = WindowManager.LayoutParams.WRAP_CONTENT;
		imageViewLP.height = WindowManager.LayoutParams.WRAP_CONTENT;
		imageView.setScaleType(ImageView.ScaleType.CENTER);
		imageView.setLayoutParams(imageViewLP);
		imageView.setImageResource(cordova.getActivity().getResources().getIdentifier("back", "drawable", cordova.getActivity().getPackageName()));
		backLayout.addView(imageView);
		linearLayout.addView(backLayout);

		FrameLayout frameLayout = new FrameLayout(this.cordova.getActivity().getApplicationContext());
		FrameLayout.LayoutParams frameLayoutLP = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
		frameLayout.setLayoutParams(frameLayoutLP);

		mMessageLayout = new LinearLayout(this.cordova.getActivity().getApplicationContext());
		LinearLayout.LayoutParams mMessageLayoutLP = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
		mMessageLayoutLP.setMargins(5, 20, 5, 30);
		mMessageLayout.setBackgroundColor(Color.parseColor("#000000"));
		mMessageLayout.setPadding(40, 10, 40, 10);
		mMessageLayout.setLayoutParams(mMessageLayoutLP);
		mMessageLayout.setVisibility(GONE);

		mMessageText = new TextView(this.cordova.getActivity().getApplicationContext());
		WindowManager.LayoutParams mMessageTextLP = new WindowManager.LayoutParams();
		mMessageTextLP.width = WindowManager.LayoutParams.WRAP_CONTENT;
		mMessageTextLP.height = WindowManager.LayoutParams.WRAP_CONTENT;
		mMessageText.setLayoutParams(mMessageTextLP);
		mMessageText.setGravity(Gravity.CENTER_HORIZONTAL);
		mMessageText.setEllipsize(TextUtils.TruncateAt.END);
		mMessageText.setMaxLines(3);
		mMessageText.setTextColor(Color.parseColor("#FFFFFF"));
		mMessageText.setTextSize(20);
		mMessageText.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
		mMessageLayout.addView(mMessageText);
		frameLayout.addView(mMessageLayout);

		FrameLayout frameLayout1 = new FrameLayout(this.cordova.getActivity().getApplicationContext());
		FrameLayout.LayoutParams frameLayout1LP = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
		frameLayout1LP.gravity = Gravity.CENTER;
		frameLayout1.setLayoutParams(frameLayout1LP);

		ImageView imageView1 = new ImageView(this.cordova.getActivity().getApplicationContext());
		WindowManager.LayoutParams imageView1LP = new WindowManager.LayoutParams();
		imageView1LP.width = WindowManager.LayoutParams.MATCH_PARENT;
		imageView1LP.height = WindowManager.LayoutParams.MATCH_PARENT;
		imageView1.setPadding(20, 20, 20, 20);
		imageView1.setLayoutParams(imageView1LP);
		imageView1.setImageResource(cordova.getActivity().getResources().getIdentifier("money_frame_2", "drawable", cordova.getActivity().getPackageName()));
		frameLayout1.addView(imageView1);

		frameLayout.addView(frameLayout1);
		linearLayout.addView(frameLayout);
		baseFrame.addView(linearLayout);

		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				cameraScene = new Dialog(CameraLauncher.this.cordova.getActivity(), android.R.style.Theme_Black_NoTitleBar_Fullscreen);
				cameraScene.addContentView(baseFrame, baseFrameLP);
				cameraScene.show();
				CameraLauncher.this.cordova.getActivity().getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
				CameraLauncher.this.cordova.getActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
			}
		});

		takePermissions();

		backLayout.setOnClickListener(new View.OnClickListener() {
			@Override
			public void onClick(View arg0) {
				failPicture("cancelled");
				closeCameraScene();
			}
		});

		mSensorManager = (SensorManager) this.cordova.getActivity().getSystemService(Context.SENSOR_SERVICE);

		if (mSensorManager.getDefaultSensor(android.hardware.Sensor.TYPE_LIGHT) != null) {
			mLight = mSensorManager
					.getDefaultSensor(android.hardware.Sensor.TYPE_LIGHT);
		} else {
			hasLightSensor = false;
		}
	}

	private void closeCameraScene() {
		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				cameraScene.dismiss();
				CameraLauncher.this.cordova.getActivity().getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
				CameraLauncher.this.cordova.getActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR);
				if (progress != null) {
					progress.dismiss();
				}
				releaseCamera();
			}
		});
	}

	private void addPreview() {
		cordova.getActivity().runOnUiThread(new Runnable() {
			public void run() {
				// Create an instance of Camera
				if (mCamera == null)
					mCamera = getCameraInstance();

				if (mCamera == null) {
					failPicture("Camera is not available");
					closeCameraScene();
					return;
				}

				// Create our Preview view and set it as the content of our activity.
				mPreview = new Preview(CameraLauncher.this.cordova.getActivity(), CameraLauncher.this.cordova.getActivity().getApplicationContext(), mCamera, true, true);
				preview.addView(mPreview);

				mPreview.setOnClickListener(new View.OnClickListener() {

					@Override
					public void onClick(View v) {
						takePicture();
					}

				});
			}
		});
	}

	@Override
	public void onAccuracyChanged(android.hardware.Sensor sensor, int accuracy) {
	}

	@Override
	public void onSensorChanged(SensorEvent event) {
		float lux = event.values[0];

		if (!fixedImage) {
			if (mCamera != null) {
				Camera.Parameters p = mCamera.getParameters();

//                if (lux <= 20 && mFlashMode != Parameters.FLASH_MODE_TORCH) {
//                    mFlashMode = Parameters.FLASH_MODE_TORCH;
//                    p.setFlashMode(Parameters.FLASH_MODE_TORCH);
//                    mCamera.setParameters(p);
//                    TTSManager.getInstance().speakText(LanguageManager.getInstance().getText("common_assist_light"));
//                    mPreview.setAutoFlash(false);
//                } else if (lux > 50 && mFlashMode != Parameters.FLASH_MODE_AUTO) {
				mFlashMode = Camera.Parameters.FLASH_MODE_AUTO;
				p.setFlashMode(Camera.Parameters.FLASH_MODE_AUTO);
				mCamera.setParameters(p);
				mPreview.setAutoFlash(true);
//                }
			}
		}
	}

	private File saveImage(byte[] data) {
		File imagesFolder = new File(Environment.getExternalStorageDirectory(), "/novartis");
		imagesFolder.mkdirs();
		String fileName = "object.jpg";
		File output = new File(imagesFolder, fileName);
		try {
			FileOutputStream fos = new FileOutputStream(output);
			fos.write(data);
			fos.close();
		} catch (FileNotFoundException e) {
			LOG.d(LOG_TAG, "saveImage ex: " + e.getMessage());
			this.failPicture("saveImage ex: " + e.getMessage());
		} catch (IOException e) {
			LOG.d(LOG_TAG, "saveImage ex: " + e.getMessage());
			this.failPicture("saveImage ex: " + e.getMessage());
		}

		return new File(imagesFolder + "/" + fileName);
	}

	private void releaseCamera() {
		if (mCamera != null) {
			mPreview.setCamera(null);
			mCamera.release(); // release the camera for other applications
			mCamera = null;
		}
	}

//	public void showMessage(final String text) {
//		runOnUiThread(new Runnable() {
//
//			@Override
//			public void run() {
//				mMessageText.setText(text);
//				mMessageLayout.setVisibility(View.VISIBLE);
//			}
//		});
//	}

	public Bundle onSaveInstanceState() {
		Bundle state = new Bundle();
		mSensorManager.unregisterListener(this);
		failPicture("cancelled");
		closeCameraScene();

		return state;
	}
}
