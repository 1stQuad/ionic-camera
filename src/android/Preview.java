package cordova.plugins.CameraModule;

import android.app.Activity;
import android.content.Context;
import android.hardware.Camera;
import android.util.Log;
import android.view.Surface;
import android.view.SurfaceHolder;
import android.view.SurfaceView;

import java.util.List;

public class Preview extends SurfaceView implements SurfaceHolder.Callback {
	private static int width, height;

	private SurfaceHolder mHolder;
	private Camera mCamera;
	private Activity mActivity;
	private boolean mZoomEnabled;
	private boolean mAutoFlash;

	private static String TAG = "CAMERA_TEST";

	@SuppressWarnings("deprecation")
	public Preview(Activity activity, Context context, Camera camera, boolean enableZoom, boolean autoFlash) {
		super(context);
		mActivity = activity;
		mCamera = camera;

		mZoomEnabled = enableZoom;
		mAutoFlash = autoFlash;

		// Install a SurfaceHolder.Callback so we get notified when the
		// underlying surface is created and destroyed.
		mHolder = getHolder();
		mHolder.addCallback(this);
		// deprecated setting, but required on Android versions prior to 3.0
		mHolder.setType(SurfaceHolder.SURFACE_TYPE_PUSH_BUFFERS);
	}

	public void surfaceCreated(SurfaceHolder holder) {
		// The Surface has been created, now tell the camera where to draw the preview.
        /*try {
            Camera.Parameters parameters = mCamera.getParameters();
            Camera.Size size = getBestPreviewSize(width, height);
            parameters.setPreviewSize(size.width, size.height);

            mCamera.setPreviewDisplay(holder);
            mCamera.startPreview();
        } catch (IOException e) {
            Log.d(TAG, "Error setting camera preview: " + e.getMessage());
        }*/
	}

	public void surfaceDestroyed(SurfaceHolder holder) {
		// empty. Take care of releasing the Camera preview in your activity.
	}

	public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {
		// If your preview can change or rotate, take care of those events here.
		// Make sure to stop the preview before resizing or reformatting it.

		if (mHolder.getSurface() == null){
			// preview surface does not exist
			return;
		}

		// stop preview before making changes
		try {
			mCamera.stopPreview();
		} catch (Exception e){
			// ignore: tried to stop a non-existent preview
		}

		// set preview size and make any resize, rotate or
		// reformatting changes here

		setCameraDisplayOrientation( mActivity, Camera.CameraInfo.CAMERA_FACING_BACK, mCamera);

		Camera.Parameters parameters = mCamera.getParameters();

		List<Camera.Size> sizes = parameters.getSupportedPreviewSizes();
		Camera.Size optimalSize = getOptimalPreviewSize(sizes, width, height);

		parameters.setPreviewSize(optimalSize.width, optimalSize.height);

		sizes = parameters.getSupportedPictureSizes();
		optimalSize = getOptimalPreviewSize(sizes, width, height);

		parameters.setPictureSize(optimalSize.width, optimalSize.height);

		if (parameters.getSupportedFocusModes().contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
			parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
		}

		if (parameters.getSupportedFocusModes().contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE)) {
			parameters.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
		}

		if (parameters.getSupportedFocusModes().contains(Camera.Parameters.WHITE_BALANCE_AUTO)) {
			parameters.setWhiteBalance(Camera.Parameters.WHITE_BALANCE_AUTO);
		}

		if (parameters.getSupportedFocusModes().contains(Camera.Parameters.FLASH_MODE_AUTO) && mAutoFlash) {
			parameters.setFlashMode(Camera.Parameters.FLASH_MODE_AUTO);
		}

		if (mZoomEnabled && parameters.isZoomSupported()) {
			parameters.setZoom(10);
		}

		mCamera.setParameters(parameters);

		// start preview with new settings
		try {
			mCamera.setPreviewDisplay(mHolder);
			mCamera.startPreview();

		} catch (Exception e){
			Log.d(TAG, "Error starting camera preview: " + e.getMessage());
		}
	}

	private Camera.Size getOptimalPreviewSize(List<Camera.Size> sizes, int w, int h) {
		final double ASPECT_TOLERANCE = 0.2;

		double targetRatio = (double) w / h;
		int targetHeight = h;

		if (h>w)
		{
			targetRatio = (double) h / w;
			targetHeight = w;
		}

		if (sizes == null)
			return null;

		Camera.Size optimalSize = null;
		double minDiff = Double.MAX_VALUE;



		// Try to find an size match aspect ratio and size
		for (Camera.Size size : sizes) {
			double ratio = (double) size.width / size.height;
			if (Math.abs(ratio - targetRatio) > ASPECT_TOLERANCE)
				continue;
			if (Math.abs(size.height - targetHeight) < minDiff) {
				optimalSize = size;
				minDiff = Math.abs(size.height - targetHeight);
			}
		}

		// Cannot find the one match the aspect ratio, ignore the
		// requirement
		if (optimalSize == null) {
			minDiff = Double.MAX_VALUE;
			for (Camera.Size size : sizes) {
				if (Math.abs(size.height - targetHeight) < minDiff) {
					optimalSize = size;
					minDiff = Math.abs(size.height - targetHeight);
				}
			}
		}

		return optimalSize;
	}

	@Override
	protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
		// We purposely disregard child measurements because act as a
		// wrapper to a SurfaceView that centers the camera preview instead
		// of stretching it.
		width = resolveSize(getSuggestedMinimumWidth(),
				widthMeasureSpec);
		height = resolveSize(getSuggestedMinimumHeight(),
				heightMeasureSpec);
		setMeasuredDimension(width, height);
	}

	public static void setCameraDisplayOrientation(Activity activity, int cameraId, android.hardware.Camera camera) {
		android.hardware.Camera.CameraInfo info = new android.hardware.Camera.CameraInfo();
		android.hardware.Camera.getCameraInfo(cameraId, info);
		int rotation = activity.getWindowManager().getDefaultDisplay().getRotation();
		int degrees = 0;
		switch (rotation) {
			case Surface.ROTATION_0:
				degrees = 0;
				break;
			case Surface.ROTATION_90:
				degrees = 90;
				break;
			case Surface.ROTATION_180:
				degrees = 180;
				break;
			case Surface.ROTATION_270:
				degrees = 270;
				break;
		}

		int result;
		if (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT) {
			result = (info.orientation + degrees) % 360;
			result = (360 - result) % 360; // compensate the mirror
		} else { // back-facing
			result = (info.orientation - degrees + 360) % 360;
		}
		camera.setDisplayOrientation(result);
	}

	public int getViewWidth()
	{
		return width;
	}

	public int getViewHeight()
	{
		return height;
	}

	public Camera getCamera()
	{
		return mCamera;
	}

	public void setCamera(Camera c)
	{
		mCamera = c;
	}

	public void setAutoFlash(Boolean enabled)
	{
		mAutoFlash = enabled;
	}

}