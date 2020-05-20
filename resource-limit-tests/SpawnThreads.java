public class SpawnThreads extends Thread {
	public static void main(String args[]) throws Exception {
		Runtime runtime = Runtime.getRuntime();
        int processors = runtime.availableProcessors();
        long maxMemory = runtime.maxMemory();
        System.out.println("Number of processors: " + processors);
		int nThreads = Integer.valueOf(args[0]);
		for (int i = 0; i < nThreads; i++) {
			Thread.sleep(2000);
			(new SpawnThreads()).start();
		}
	}
	public void run() {
        System.out.println("Thread " + Thread.currentThread().get);
        while (true) {;}
    }
}