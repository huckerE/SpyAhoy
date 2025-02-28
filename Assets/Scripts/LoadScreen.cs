using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class LoadScreen : MonoBehaviour
{
    public string levelToLoad;

    public GameObject loadingScreen;

    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space))
        {
            loadingScreen.SetActive(true);
            //SceneManager.LoadScene(levelToLoad);
            StartCoroutine(LoadLevelAsync());
        }
    }

    private IEnumerator LoadLevelAsync()
    {
        AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(levelToLoad);

        while (!asyncLoad.isDone)
        {
            yield return null;
        }
    }
}
